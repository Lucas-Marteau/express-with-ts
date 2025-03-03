#!/bin/bash

baseAdress=$(pwd)
basename=$(basename "$1")
declare -a created_paths=()

read_input() {
  if [[ $# -gt 2 || $# -eq 0 ]]; then
    print_colored "bad usage of function, this function requires 1 or 2 parameters" "failure"
    return 2
  fi

  local message="$1"
  local defaultValue="$2"

  print_colored "$message"

  while true; do
      read -p "> " answer

      if [ $# -eq 2 ]; then
        local str_lower=$(echo "$answer" | tr '[:upper:]' '[:lower:]')

        if [ -z "$answer" ]; then
          return $defaultValue
        fi
        if [ "$str_lower" == "y" ]; then
          return 0
        fi
        if [ "$str_lower" == "n" ]; then
          return 1
        fi
      else
        if [[ $answer =~ ^[0-9]+$ ]]; then
          usingPORT=$answer
          return 0
        fi
      fi

      print_colored "Invalid input" "failure" 0
  done

}
print_colored() {

  if [[ $# -gt 3 || $# -eq 0 ]]; then
    echo "\033[0;31mFailure: bad usage of function, this requires 1 or 2 parameters\033[0m"
    return
  fi
  local message="$1"
  local type="$2"
  local writeType=1

  if [ $# -eq 3 ]; then
    writeType=$3
  fi

  case "$type" in
    success)
      if [ $writeType == 1 ]; then
        color="\033[0;32mSuccess: "
      else
        color="\033[0;32m"
      fi
      ;;
    warning)
      if [ $writeType == 1 ]; then
        color="\033[0;33mWarning: "
      else
        color="\033[0;33m"
      fi
      ;;
    failure)
      if [ $writeType == 1 ]; then
        color="\033[0;31mFailure: "
      else
        color="\033[0;31m"
      fi
      ;;
    *)
      color="\033[0m";;
  esac
  echo -e "${color}${message}\033[0m"
}
reccursively_create_dir() {
  if [ $# -ne 1 ]; then
    print_colored "bad usage, only one argument is required" "failure"
    return 1
  fi

  totalAdress="$1"
  dirToCreate=$(echo "$totalAdress" | cut -d '/' -f 1)

  if [[ "$totalAdress" == ./* ]]; then
    totalAdress="${totalAdress:2}"
    reccursively_create_dir $totalAdress
    return 0
  fi
  remainingPath="${totalAdress#*/}"

  if [ -e "$dirToCreate" ] && [ ! -d "$dirToCreate" ]; then
    print_colored "$(pwd)/$dirToCreate: file exists, end of the program" "failure"
    return 1
  fi

  if [ ! -d "$dirToCreate" ]; then
    created_paths+=("$(pwd)/$dirToCreate")
    mkdir "$dirToCreate"
    print_colored "$(pwd)/$dirToCreate" "success"
  else
    print_colored "$(pwd)/$dirToCreate: already exists" "warning"
  fi

  cd "$dirToCreate"

  if [ $dirToCreate == $basename ]; then
    return 0;
  fi

  reccursively_create_dir $remainingPath
}
remove_paths() {
  for path in "${created_paths[@]}"; do
    rm -rf "$path"
    print_colored "removing $path" "failure"
  done
}

if [ $# -ne 1 ]; then
    print_colored "only one argument is required: the path of the directory you want to create" "failure"
    exit 1
fi

ping -c 4 8.8.8.8 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  print_colored "please check your connexion" "failure"
  exit 1
fi

if [ ! -d "$1" ]; then
  if ! reccursively_create_dir "$1"; then
    remove_paths
    exit 1
  fi
else
  read_input "Directory already existing, are you sure you want to create an express app with TS inside $1 ? (y/N)" 1
  if [ $? -eq 1 ]; then
    print_colored "End of the program" "success" 0
    exit 0
  fi
  cd "$1"
fi

print_colored "Initialising the package.json file"

npm init -y > /dev/null 2>&1
if [ $? -ne 0 ]; then
    print_colored "npm init -y went wrong, end of program" "failure"
    cd ~
    cd "$baseAdress"
    rm -rf $1
    exit 1
fi

echo "{
  \"name\": \"$basename\",
  \"version\": \"1.0.0\",
  \"description\": \"description of $basename project\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"tsx --watch --env-file .env src/index.ts\",
    \"start\": \"node --env-file .env dist/index.js\",
    \"build\": \"tsc\",
    \"type-check\": \"tsc --noEmit\",
    \"lint\": \"eslint .\",
    \"lint:fix\": \"eslint --fix .\",
    \"test\": \"echo \\\"Error: no test specified\\\" && exit 1\"
  },
  \"keywords\": [],
  \"author\": \"$(whoami)\",
  \"license\": \"MIT\",
  \"imports\": {
    \"@*\": \"./src/*\"
    }
}" > package.json

print_colored "npm init -y done with success" "success"
print_colored "Installing express for the project"

npm i express > /dev/null 2>&1
if [ $? -ne 0 ]; then
  print_colored "express not installed" "failure"
  remove_paths
  exit 1
fi

print_colored "installation of express" "success"

read_input "Do you want to use eslint ? (Y/n)" 0
if [ $? -eq 0 ]; then
  print_colored "Installing dependencies for eslint"
  npm i -D eslint typescript-eslint @eslint/js eslint-plugin-perfectionist > /dev/null 2>&1

  if [ $? -ne 0 ]; then
    print_colored "installation of dependencies failed, end of program" "failure"
    remove_paths
    exit 1
  fi

  print_colored "installation of eslint dependancies" "success"
  print_colored "Creating eslint file"

  echo "// @ts-check

  import eslint from \"@eslint/js\";
  import tseslint from \"typescript-eslint\";

  export default tseslint.config(
    eslint.configs.recommended,
    tseslint.configs.recommended,
  );
  " > eslint.config.js

  print_colored "file eslint.config.js created" "success"
fi

read_input "Do you want to use a .env file ? (Y/n)" 0

if [ $? -eq 0 ]; then
  read_input "Which port you want to use for your application ?"
  echo "PORT=$usingPORT" > .env
  print_colored ".env file created with port $usingPORT" "success"
  beginstring="import express from \"express\";

  const app = express();
  const port = process.env.PORT ?? \"9001\";"
else
  print_colored "Chosing 3000 as default port" "success"
  beginstring="import express from \"express\";

  const app = express();
  const port = 3000"
fi

print_colored "Creating src directory"
mkdir src > /dev/null 2>&1

if [ $? -ne 0 ]; then
  print_colored "directory src not created, end of program" "failure"
  remove_paths
fi

print_colored "directory src created" "success"

totalString="$beginstring

app.get(\"/\");

app.listen(port, () => {
  console.log(\`$basename app listening on port \${port}\`);
});"
echo "$totalString" > ./src/index.ts

print_colored "./src/index.ts created !" "success"
print_colored "Installing typescript dependencies"

npm i -D @tsconfig/node22 tsx typescript @types/node @types/express @tsconfig/node-lts > /dev/null 2>&1
if [ $? -ne 0 ]; then
  print_colored "problem with typescript dependencies installation, end of program" "failure"
  exit 1
fi

print_colored "installation of typescript dependencies" "success"
print_colored "Creation of tsconfig.json file"
echo "{
  \"extends\": \"@tsconfig/node22/tsconfig.json\",
  \"compilerOptions\": {
    \"outDir\": \"./dist\",
    \"rootDir\": \"./src\"
  },
  \"include\": [\"**/*.ts\"],
  \"exclude\": [\"dist\"]
}" > tsconfig.json
print_colored "tsconfig.json file created" "success"

read_input "Do you want to use a JWT authentication on your application ? (y/N)" 1

print_colored "Creation of .gitignore file"
echo "# Environment variables
.env
.env.*
!.env.example

# Dependencies
/node_modules

# TypeScript build output
/dist

# OS generated files
.DS_Store

# Test coverage
/coverage" > .gitignore
print_colored ".gitignore file created" "success"

exit 0