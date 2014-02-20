#!/bin/sh

cd /home/git

if [ ! -d ./.gitolite ] ; then
   # if there is an existing repositories/ folder, it must
   # have been bind-mounted; we need to make sure it has the
   # correct access permissions.
   if [ -d ./repositories ] ; then
       chown -R git:git repositories
   fi

   # gitolite needs to be setup
   if [ -n "$SSH_KEY" ]; then
       echo "Initializing gitolite with key"
       echo "$SSH_KEY" > /tmp/admin.pub
       su git -c "bin/gitolite setup -pk /tmp/admin.pub"
       rm /tmp/admin.pub
   else
       # If no SSH key is given, we instead try to support
       # bootstrapping from an existing gitolite-admin. 

       # Unfortunately, gitolite setup will add a new 
       # commit to an existing gitolite-admin dir that 
       # resets everything. We avoid this by renaming it first.
       if [ -d ./repositories/gitolite-admin.git ]; then
           mv ./repositories/gitolite-admin.git ./repositories/gitolite-admin.git-tmp
       fi
      
       # First, setup gitolite without an ssh key.
       # My understanding is that this is essentially a noop,
       # auth-wise. setup will still generate the .gitolite 
       # folder and .gitolite.rc files.
       echo "Initializing gitolite without a key"
       su git -c "bin/gitolite setup -a dummy"

       # Remove the gitolite-admin repo generated by setup.
       if [ -d ./repositories/gitolite-admin.git-tmp ]; then
           rm -rf ./repositories/gitolite-admin.git
           mv ./repositories/gitolite-admin.git-tmp ./repositories/gitolite-admin.git
       fi

       # Apply config customizations. We need to do this now,
       # because w/o the right config, the compile may fail.
       sed -i "s/GIT_CONFIG_KEYS.*=>.*''/GIT_CONFIG_KEYS => \"${GIT_CONFIG_KEYS}\"/g" /home/git/.gitolite.rc

       # We will need to update authorized_keys based on
       # the gitolite-admin repo. The way to do this is by
       # triggering the post-update hook of the gitolite-admin
       # repo (thanks to sitaram for the solution):
       su git -c "cd /home/git/repositories/gitolite-admin.git && GL_LIBDIR=$(/home/git/bin/gitolite query-rc GL_LIBDIR) PATH=$PATH:/home/git/bin hooks/post-update refs/heads/master"
   fi
else
    # Resync on every restart
    su git -c "bin/gitolite setup"
fi

exec $*
