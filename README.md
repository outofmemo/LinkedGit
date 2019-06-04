# LinkedGit

`Linked-Git` is a script which wraps `git ` to provide mutil-workspace support. 

##  What's it for?

As we know, a git repositary maintains only one workspace which shared by all branches.

When we need to switch to another branch, we can use command `git checkout `. However, there may be some useful modifications or untracked files we can't commit. At this time, we can't simply check out another branch without extra process.  One solution for this problem is to create dedicated workspaces for each branch. And `Linked-Git` is used to implement this solution.

## How to use it?

*   Firstly, install it.

    ```sh
    wget https://raw.githubusercontent.com/outofmemo/LinkedGit/master/LinkedGit.sh
    chmod +x LinkedGit.sh
    sudo ./LinkedGit.sh install
    ```

    After you have installed it, the original `git` has been move to `git_org`,  and the script has been wirtten as `git`. This script provides two command:

    *   `git link <GitPath> [Branch]` : Transform the current working directory into a fake git workspace which works on the specified branch.
    *   `git unlink ` : Transform a fake git workspace into a normal directory .

*   Then, create some workspace copies

    ```sh
    # Assume your git repositary is at '/project/repo/.git'
    cd /project
    # Create workspace 'workspace1' which works on (new) branch 'branch1'
    mkdir /project/workspace1
    cd /project/workspace1
    git link ../repo branch1
    # Create workspace 'workspace2' which works on (new) branch 'branch2'
    mkdir /project/workspace2
    cd /project/workspace2
    git link ../repo branch2
    ```

    Now, there are:

    *   A git repositary at '/project/repo/.git'
    *   A real git workspace at '/project/repo'
    *   A fake git workspace at '/project/workspace1' linked to '/project/repo/.git' which works on 'branch1'
    *   A fake git workspace at '/project/workspace2' linked to '/project/repo/.git' which works on 'branch2'

    All these workspaces share a single git repositary without affecting each other.

    Even in a fake git workspace, you can use almost all git commands. But be careful about renaming branches(`git branch -m`), which may cause some troubles. 

