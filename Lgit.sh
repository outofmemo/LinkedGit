#!/usr/bin/env bash
# Lgit: Add multi-workspace support for git
# Contact: oufme@outlook.com or https://github.com/outofmemo/Lgit/issue

self=$0
# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

print_error(){
    echo -e "${red}Error: $1$plain" >&2
}

print_warning(){
    echo -e "${yellow}Warning: $1$plain" >&2
}

print_info(){
    echo "Lgit: $1"
}

remove_relative_symbol() {
    local name=$1
    local path=$2
    
    path=$path/
    path=`echo $path | sed "s/\/\//\//"`
    path=`echo $path | sed "s/\/\.\//\//"`
    path=`echo $path | sed "s/[0-9,a-w,A-W,-,_,.]*\/\.\.\///"`
    if [[ "$path" = */ ]]; then
        path=${path%/*}
    fi
    
    if [[ "$path" = ./* ]]; then
        path=${path#*/}
    fi
    
    eval "$name=$path"
}

resolve_relative_path() {
    # Full absolute destination path
    local dest_path=$1
    # Full absolute work path
    local work_path=$2
    local relative_path
    local dest_name
    local work_name
    
    #remove_relative_symbol dest_path $dest_path
    #remove_relative_symbol work_path $work_path
    
    # Firstly, search the common parent directory
    while [[ -n "$dest_path" ]]; do
        dest_path=${dest_path#*/}
        work_path=${work_path#*/}
        dest_name=${dest_path%%/*}
        work_name=${work_path%%/*}
        
        if [[ "$dest_name" != "$work_name" ]]; then
            break
        fi
    done
    
    # Secondly, go to the common parent directory
    if [[ -n "$work_path" && "$work_path" != "*/" ]]; then
        work_path=$work_path/
    fi
    while [[ -n "$work_path" ]]; do
        work_path=${work_path#*/}
        relative_path=${relative_path}../
    done
    
    # Lastly, go to the destination directory
    relative_path=${relative_path}$dest_path
    
    eval "$3=$relative_path"
}

find_git_path(){
    # Full absolute work path
    local work_path=$1

    while [[ -n "$work_path" ]] && [[ ! -d "$work_path/.git" ]]; do
        work_path=${work_path%/*}
    done

    if [[ -n "$work_path" ]]; then
        eval "$2=$work_path/.git"
    else 
        eval "$2=''"
    fi
}

Lgit_exec(){
    local work_path
    local git_dir
    local work_git_path
    local real_git_path
    local link_prefix
    local image_prefix
    local ret

    if [[ -z "$org_git" ]]; then
        print_error "Lgit is not installed, run '$0 install' first."
        exit 1
    fi

    work_path=`pwd`
    find_git_path "$work_path" work_git_path

    if [[ -z "$work_git_path" ]]; then
        # Can't find .git, let orginal git solve it
        $org_git $@
        exit $?
    fi

    cd "$work_git_path/.."

    if [[ -r .git/git_dir ]]; then
        git_dir=`cat .git/git_dir`
        real_git_path=$git_dir
    else 
        git_dir=''
        real_git_path=".git"
    fi  

    if [[ -n "$git_dir" ]]; then
        [[ -f "$real_git_path/org_HEAD" && -f "$real_git_path/org_index" ]] || {
            print_error "It's a fake git repository, and the real git repository is not ready."
            exit 1
        }
    fi

    if [[ -n "$git_dir" ]] || [[  -f "$real_git_path/org_HEAD" && -f "$real_git_path/org_index"  ]]; then
        # Make it absolute
        cd "$real_git_path"
        real_git_path=`pwd`

        rm index || {
            print_error "Remove index failed."
            exit 1
        }

        if [[ -n "$git_dir" ]]; then
            # Fake git repository 
            if [[ "$git_dir" = /* ]]; then
                # If "git-dir" is an absolute path, use absolute path to link
                link_prefix=$work_git_path/
            else
                # If "git-dir" is an relative path, use relative path to link
                resolve_relative_path "$work_git_path" "$real_git_path" link_prefix
                link_prefix=$link_prefix/
            fi
            image_prefix=$work_git_path/
        else
            # Linked real git repository 
            link_prefix=./org_
            image_prefix=$work_git_path/org_
        fi

        if [[ -f "$real_git_path/index.lock" ]]; then
            print_error "'$real_git_path/index.lock' exists, maybe another instance is running."
            exit 1
        fi
        
        ln -s "${link_prefix}index" index || {
            print_error "Link index failed."
            exit 1
        }

        cat "${image_prefix}HEAD" > HEAD || {
            print_error "Switch HEAD failed."
            exit 1
        }

        cd "$work_path"
        trap "cat '$real_git_path/HEAD' > '${image_prefix}HEAD'" SIGTERM SIGINT SIGHUP SIGQUIT

        if [[ -n "$git_dir" ]]; then
            # Fake repository
            $org_git --git-dir="$git_dir" $@
        else
            # Real repository
            $org_git $@
        fi
        ret=$?

        cat "$real_git_path/HEAD" > "${image_prefix}HEAD" || {
            print_error "Sync HEAD failed."
            exit 1
        }

        exit $ret
    else 
        # Original real git repository 
        $org_git $@
        exit $?
    fi
}

Lgit_help(){
    echo "Lgit commands:"
    echo "      install                 Install Lgit."
    echo "      uninstall               Uninstall Lgit."
    echo "      link <path> [branch]    Link this workspace to a git repository."
    echo "      unlink                  Unlink this workspace."
}

write_script(){
    local Lgit_path=$1
    local org_git=$2
    local var_inserted=''
    local IFS_old=$IFS

    if [[ -f "$Lgit_path" ]]; then
        rm "$Lgit_path" || {
            print_error "Remove '$Lgit_path' failed."
        }
    fi

    print_info "Writing Lgit to '$Lgit_path'."

    IFS=''
    while read -r line; do
        if [[ -z "$var_inserted" ]]; then
            if [[ -z "$line" || "$line" = \#* ]]; then
                echo "$line" >>"$Lgit_path"
            else 
                echo "org_git='$org_git'" >>"$Lgit_path"
                echo "$line" >>"$Lgit_path"
                var_inserted='y'
            fi
        else
            echo "$line" >>"$Lgit_path"
        fi
    done < $self
    IFS=$IFS_old

    if [[ -z "$var_inserted" ]]; then
        print_error "Write script failed."
        exit 1
    fi
}

Lgit_install(){
    local exe_git_path
    local bak_git_path

    if [[ -n "$org_git" ]]; then
        print_error "Lgit is already installed."
        exit 1
    fi

    git --version || {
        print_error "Git is not installed, install git first."
        exit 1
    }

    exe_git_path=`which git`

    if [[ -z "$exe_git_path" ]]; then
        print_error "Can't find git."
        exit 1
    fi

    cat "$exe_git_path" | grep -q  "Lgit_link()" && {
        print_info "An old Lgit installed, uninstall '$exe_git_path'..."
        "$exe_git_path" uninstall || {
            "Uninstall old Lgit failed."
            exit 1
        }
        "$self" install
        return
    }

    if [[ -f "${exe_git_path}_org" ]]; then
        bak_git_path="${exe_git_path}_org-"`date "%Y-%m-%d-%H-%M-%S"`
        print_warning "'${exe_git_path}_org' exists, backup it to '$bak_git_path'"
        mv "${exe_git_path}_org" "$bak_git_path" || {
            print_error "Backup '${exe_git_path}_org' failed."
            exit 1
        }
    fi

    print_info "Move '${exe_git_path}' to '${exe_git_path}_org'"

    mv "${exe_git_path}" "${exe_git_path}_org" || {
        print_error "Move '${exe_git_path}' failed."
        exit 1
    }

    write_script "${exe_git_path}" "${exe_git_path}_org"

    chmod a+x "${exe_git_path}" || {
        print_error "Change file mode failed."
        exit 1
    }

    print_info "Install finished."
}

Lgit_uninstall(){
    if [[ -z "$org_git" ]]; then
        print_error "Lgit is not installed."
    fi

    print_info "Remove '$self'"
    rm "$self" || {
        print_error "Remove '$self' failed."
        exit 1
    }

    print_info "Move '${self}_org' to '${self}''"

    mv "${self}_org" "${self}" || {
        print_error "Move '${self}_org' failed."
        exit 1
    }

    print_info "Uninstall finished."
}

Lgit_link(){
    local git_path=$2
    local branch=$3
    local git_dir

    if [[ -z "$git_path" ]]; then
        print_error "Git path must be specified."
        Lgit_help
        exit 1
    fi

    if [[ -f .git/git_dir ]]; then
        git_dir=`cat .git/git_dir`
        print_error "This workspace is already linked to '$git_dir'."
        print_error "Run 'git unlink' first."
        exit 1
    fi

    if [[ "$git_path" != */.git ]] && [[ "$git_path" != */.git/ ]]; then
        if [[ "$git_path" = */ ]];then
            git_path=${git_path}.git
        else
            git_path=$git_path/.git
        fi
    fi

    if [[ ! -f $git_path/org_HEAD ]]; then
        cp "$git_path/HEAD" "$git_path/org_HEAD" || {
            print_error "Backup HEAD failed."
            exit 1
        }
    fi

    if [[ ! -f $git_path/org_index ]]; then
        cp "$git_path/index" "$git_path/org_index" || {
            print_error "Backup index failed."
            exit 1
        }
    fi

    if [[ ! -d .git ]]; then
        mkdir .git || {
            print_error "Create .git failed."
            exit 1
        }

        cp "$git_path/org_HEAD" .git/HEAD || {
            print_error "Copy HEAD failed."
            exit 1
        }

        echo "$git_path" > .git/git_dir || {
            print_error "Write git-dir failed."
            exit 1
        }

        print_info "Linked to '${git_path}'."

        if [[ -n "$branch" ]]; then
            if [[ -f $git_path/refs/heads/$branch ]]; then
                Lgit_exec checkout "$branch"
            else
                Lgit_exec checkout -b "$branch"
            fi
        else
            print_warning "It's better to keep workspaces on different branchs, \
use 'git checkout [-b] <branch>' to checkout a branch."
        fi

    else 
        print_error "This workspace seems to be a real git repository."
    fi

}

Lgit_unlink(){
    if [[ ! -d .git ]]; then
        print_error "Not a git workspace."
        exit 1
    fi

    if [[ ! -f .git/git_dir ]] || [[ -d .git/refs ]]; then
        print_error "This workspace seems to be a real git repository."
        exit 1
    fi

    rm -r .git || {
        print_error "Remove .git failed!"
        exit 1
    }

    print_info "Unlinked."
}

action=$1
if [[ -z "$action" ]]; then
    $org_git
    Lgit_help
    exit
fi

case "$action" in
    install|uninstall|link|unlink)
        Lgit_$action $@
        ;;
    *)
        Lgit_exec $@
        ;;
esac
