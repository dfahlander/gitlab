#!/bin/bash -e

if ! [ -e build/release.sh ]; then
  echo >&2 "Please run build/release.sh from the repo root"
  exit 1
fi

update_version() {
  echo "$(node -p "p=require('./${1}');p.version='${2}';JSON.stringify(p,null,2)")" > $1
  echo "Updated ${1} version to ${2}"
}

validate_semver() {
  if ! [[ $1 =~ ^[0-9]\.[0-9]+\.[0-9](-.+)? ]]; then
    echo >&2 "Version $1 is not valid! It must be a valid semver string like 1.0.2 or 2.3.0-beta.1"
    exit 1
  fi
}

current_version=$(node -p "require('./package').version")

# Next version?
printf "Next version (current is $current_version)? "
read next_version

validate_semver $next_version

next_ref="v$next_version"

update_version 'package.json' $next_version

# Commit package.json change
git commit package.json --allow-empty -m "Released v$next_version"
# Save this SHA to cherry pick later
master_release_commit=$(git rev-parse HEAD)

#
# Merge last release output here before rebuilding
#
git merge --no-edit -s ours origin/releases

#
# Rebuild
#

# clean
rm -rf build/tmp
# build
npm run build
# test
npm test

# Dont include the README because it tells us about missing files (which is not missing now)
rm -f dist/README.md
# Force adding/removing dist files
git add -A --no-ignore-removal -f dist/ 2>/dev/null

# Commit all changes (still locally)
git commit -am "Build output" 2>/dev/null
# Tag the release
git tag $next_ref
git tag latest -f
# Now, push the changes to the releases branch
git push origin master:releases
printf "Successful push to master:releases\n"

#npm publish

printf "Successful publish to npm.\n"

# Push the update of package.json to master
printf "Pushing Release-commit to master (with updated version in package.json)\n"
git push origin $master_release_commit:master

printf "Resetting to origin/master\n"
git reset --hard origin/master

printf "Done."
