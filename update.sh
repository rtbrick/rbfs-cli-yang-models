#!/bin/bash
VERSION=${1}
BRANCH=${2}
TAG=${3}

function prepareGit() {
  git checkout main
  git pull
  git checkout -b "$BRANCH" || true
  git checkout "$BRANCH"
  git pull
  rm -rf accessleaf
  rm -rf consolidated-bng
  rm -rf l2bsa
  rm -rf spine
}
function commitGit() {
  git add .
  git commit -m "Add yang files for $VERSION" -m "/update.sh \"$VERSION\" \"$BRANCH\" \"$TAG\""
  git push --set-upstream origin "$BRANCH"
  git tag "$TAG"
  git push origin tag "$TAG"
}
function loadData() {
   # Use jq to iterate over each item in the array directly
   rtb-image list -v "$VERSION" -f lxd -O json \
     | jq -c '.[] | select(.Platform != "all" and .Platform != "virtual")' \
     | while IFS= read -r item; do
     uuid=$(echo "$item" | jq -r '.UUID')
     platform=$(echo "$item" | jq -r '.Platform')
     model=$(echo "$item" | jq -r '.Model')
     role=$(echo "$item" | jq -r '.Role')
     version=$(echo "$item" | jq -r '.Version')

     todir="$role/$model"
     mountdir="temp/mount"
     # Use the extracted 'UUID' and 'Platform' in your script
     if [[ "$model" == "combined" ]]; then
       todir="$role/$model/$platform"
     fi

     # Normal processing
     echo "Processing $uuid $role $model $platform $version"
     echo "* pull $uuid"
     sudo rtb-image pull "$uuid"

     mkdir -p "temp"
     echo "* mount $mountdir"
     sudo rtb-image mount -d "$mountdir" "$uuid"

     echo "* to dir $todir"
     mkdir -p "$todir"
     echo "copy from $mountdir/usr/share/rtbrick/rtbcli/yang to $todir"

     sudo cp -r "$mountdir/usr/share/rtbrick/rtbcli/yang" "$todir"
     echo "done"

     echo "* umount $mountdir"
     sudo umount "$mountdir"
     sudo rm -rf "temp"
   done
   sudo chown -R "$USER:$USER" .
}

prepareGit
loadData
commitGit
