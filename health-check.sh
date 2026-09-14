# In the original repository we'll just print the result of status checks,
# without committing. This avoids generating several commits that would make
# later upstream merges messy for anyone who forked us.
commit=true
origin=$(git remote get-url origin)
if [[ $origin == *statsig-io/statuspage* ]]
then
  commit=false
fi

KEYSARRAY=()
URLSARRAY=()

urlsConfig="./urls.cfg"
echo "Reading $urlsConfig"
while read -r line
do
  echo "  $line"
  IFS='=' read -ra TOKENS <<< "$line"
  KEYSARRAY+=(${TOKENS[0]})
  URLSARRAY+=(${TOKENS[1]})
done < "$urlsConfig"

echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs

for (( index=0; index < ${#KEYSARRAY[@]}; index++))
do
  key="${KEYSARRAY[index]}"
  url="${URLSARRAY[index]}"
  echo "  $key=$url"

  for i in 1 2 3 4;
  do
      response=$(curl \
          --location \
          --write-out '%{http_code}' \
          --silent \
          --output /dev/null \
          --user-agent 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140 Safari/537.36' \
          "$url")

      curl_exit=$?

      echo "    Attempt $i: HTTP $response, curl exit $curl_exit"

      if [ "$response" -eq 200 ] || \
         [ "$response" -eq 202 ] || \
         [ "$response" -eq 301 ] || \
         [ "$response" -eq 302 ] || \
         [ "$response" -eq 307 ]; then
          result="success"
      else
          result="failed"
      fi
  done
  dateTime=$(date +'%Y-%m-%d %H:%M')
  if [[ $commit == true ]]
  then
    echo $dateTime, $result >> "logs/${key}_report.log"
    # By default we keep 2000 last log entries.  Feel free to modify this to meet your needs.
    echo "$(tail -2000 logs/${key}_report.log)" > "logs/${key}_report.log"
  else
    echo "    $dateTime, $result"
  fi
done

if [[ $commit == true ]]
then
  git config --global user.name 'github-actions[bot]'
  git config --global user.email '41898282+github-actions[bot]@users.noreply.github.com'
  git add -A --force logs/
  git commit -am '[Automated] Update Health Check Logs'
  git push
fi
