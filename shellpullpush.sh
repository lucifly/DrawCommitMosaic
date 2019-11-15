echo "a" >> aass 
git add .
echo $1
git commit --amend --date="$1" -a -m "$1"
git pull
git push
