# Usage

```
docker ps

git clone https://example.com/get-gitlab-issues.git
cd get-gitlab-issues

cat <<EOF > .env
GITLAB_TOKEN = gitlab-personal-token
GROUP = groupname_or_groupid
DISCUSSION_GROUP_PROJECT = groupname/projectname
DISCUSSION_ISSUE_ID = 42
EOF

./run.sh
```
