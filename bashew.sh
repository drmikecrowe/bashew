#!/usr/bin/env bash
readonly script_author="peter@forret.com"
readonly script_fname=$(basename "$0")
readonly script_name=$(basename "$0" .sh)
# runasroot: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root
readonly runasroot=-1

list_options() {
  echo -n "
#commented lines will be filtered
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|f|force|do not ask for confirmation (always yes)
#option|m|model|template script to use: small/normal|normal
option|t|tmpd|folder for temp files|.tmp
option|l|logd|folder for log files|log
param|1|action|action to perform: script/project/init/update
" | grep -v '^#'
}

list_examples() {
  echo -n "
$script_fname script  : create new (stand-alone) script (interactive)
$script_fname project : create new bash script repo (interactive)
$script_fname init    : initialize this repo as a new project (when generated from the 'bashew' template repo)
$script_fname update  : update repo (git pull)
" | grep -v '^$'

}
## Put your helper scripts here
get_author_data() {
  # $1 = proposed script/project name
  announce "1. first we need the information of the author"
  guess_fullname="$(whoami)"
  guess_username="$guess_fullname"
  guess_email="$guess_fullname@$(hostname)"

  [[ -n ${BASHEW_AUTHOR_FULLNAME:-} ]] && guess_fullname="$BASHEW_AUTHOR_FULLNAME"
  [[ -n ${BASHEW_AUTHOR_EMAIL:-} ]] && guess_email="$BASHEW_AUTHOR_EMAIL"
  [[ -n ${BASHEW_AUTHOR_USERNAME:-} ]] && guess_username="$BASHEW_AUTHOR_USERNAME"

  if is_set "$in_git_repo"; then
    guess_fullname=$(git config user.name)
    guess_email=$(git config user.email)
    guess_username=$(git config remote.origin.url | cut -d: -f2)
    # git@github.com:pforret/bashew.git => pforret/bashew.git
    guess_username=$(dirname "$guess_username")
    # pforret/bashew.git => pforret
    guess_username=$(basename "$guess_username")
  fi
  author_fullname=$(ask "Author full name        " "$guess_fullname")
  author_email=$(   ask "Author email            " "$guess_email")
  author_username=$(ask "Author (github) username" "$guess_username")

  # save for later
  export BASHEW_AUTHOR_FULLNAME="$author_fullname"
  export BASHEW_AUTHOR_EMAIL="$author_email"
  export BASHEW_AUTHOR_USERNAME="$author_username"

  announce "2. now we need the path and name of this new script/repo"
  new_name=$(ask "Script name" "$1")
  announce "3. give some description of what the script should do"
  clean_name=$(basename "$new_name" .sh)
  new_description=$(ask "Script description" "This is my script $clean_name")
}

copy_and_replace() {
  local input="$1"
  local output="$2"

    < "$input" \
      sed "s/author_name/$author_fullname/g" \
    | sed "s/author_username/$author_username/g" \
    | sed "s/author@email.com/$author_email/g" \
    | sed "s/package_name/$clean_name/g" \
    | sed "s/package_description/$new_description/g" \
    | sed "s/meta_thisday/$thisday/g" \
    | sed "s/meta_thisyear/$thisyear/g" \
    > "$output"
}

random_word() {
  (
    if aspell -v >/dev/null; then
      aspell -d en dump master | aspell -l en expand
    elif [[ -f /usr/share/dict/words ]]; then
      cat /usr/share/dict/words
    elif [[ -f /usr/dict/words ]]; then
      cat /usr/dict/words
    else
      printf 'zero\none\ntwo\nthree\nfour\nfive\nsix\nseven\nseight\nnine\n%.0s' {1..10000}
    fi
  ) |
    grep -v "'" |
    grep -v " " |
    awk "NR == $RANDOM {print tolower(\$0)}"
}

#####################################################################
## Put your main script here
#####################################################################

main() {
  log "Program: $script_fname $script_version"
  log "Updated: $script_modified"
  log "Run as : $USER@$HOSTNAME"
  # add programs you need in your script here, like tar, wget, ffmpeg, rsync ...
  verify_programs awk basename cut date dirname find grep head mkdir sed stat tput uname wc

  action=$(lcase "$action")
  case $action in
  script)
    random_name="$(random_word)_$(random_word).sh"
    get_author_data "./$random_name"
    announce "Creating script $new_name ..."
    copy_and_replace "$script_install_folder/template/normal.sh" "$new_name"
    ;;

  project)
    random_name="$(random_word)_$(random_word)/"
    get_author_data "./$random_name"
    if [[ ! -d "$new_name" ]] ; then
      announce "Creating project $new_name ..."
      mkdir "$new_name"
      template_folder="$script_install_folder/template"
      for file in "$template_folder"/*.md "$template_folder/LICENSE" "$template_folder"/.gitignore  ; do
        bfile=$(basename "$file")
        echo -n "$bfile "
        new_file="$new_name/$bfile"
        copy_and_replace "$file" "$new_file"
      done
      echo -n "$clean_name.sh "
      copy_and_replace "$template_folder/normal.sh" "$new_name/$clean_name.sh"
      chmod +x "$new_name/$clean_name.sh"
      echo " "
      if confirm "Do you want to 'git init' the new project?" ; then
        ( pushd "$new_name" && git init && git add . && popd || return) > /dev/null 2>&1
      fi
      success "next step: 'cd $new_name' and start scripting!"
    else
      alert "Folder [$new_name] already exists, cannot make a new project there"
    fi
    ;;

  init)
    #TODO: clean up templated repo
    ;;

  update)
    #TODO:
    ;;
    *)

    die "param [$action] not recognized"
    ;;
  esac
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
hash() {
  # shellcheck disable=SC2230
  if [[ -n $(which md5sum) ]]; then
    # regular linux
    md5sum | cut -c1-6
  else
    # macos
    md5 | cut -c1-6
  fi
}

script_modified="??"
os_uname=$(uname -s)
[[ "$os_uname" == "Linux" ]] && script_modified=$(stat -c %y "$0" 2>/dev/null | cut -c1-16) # generic linux
[[ "$os_uname" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "$0" 2>/dev/null)          # for MacOS

force=0
help=0

## ----------- TERMINAL OUTPUT STUFF

[[ -t 1 ]] && piped=0 || piped=1 # detect if out put is piped
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

[[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported

if [[ $piped -eq 0 ]]; then
  col_reset="\033[0m"
  col_red="\033[1;31m"
  col_grn="\033[1;32m"
  col_ylw="\033[1;33m"
else
  col_reset=""
  col_red=""
  col_grn=""
  col_ylw=""
fi

if [[ $unicode -gt 0 ]]; then
  char_succ="✔"
  char_fail="✖"
  char_alrt="➨"
  char_wait="…"
else
  char_succ="OK "
  char_fail="!! "
  char_alrt="?? "
  char_wait="..."
fi

readonly nbcols=$(tput cols || echo 80)
#readonly nbrows=$(tput lines)
readonly wprogress=$((nbcols - 5))

out() { ((quiet)) || printf '%b\n' "$*"; }

progress() {
  ((quiet)) || (
    ((piped)) && out "$*" || printf "... %-${wprogress}b\r" "$*                                             "
  )
}

die() {
  tput bel
  out "${col_red}${char_fail} $script_fname${col_reset}: $*" >&2
  safe_exit
}

alert() { out "${col_red}${char_alrt}${col_reset}: $*" >&2; } # print error and continue
success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
announce() { out "${col_grn}${char_wait}${col_reset}  $*" ; sleep 1 ;}
log() { ((verbose)) && out "${col_ylw}# $* ${col_reset}"; }

escape() { echo "$*" | sed 's/\//\\\//g'; }

lcase() { echo "$*" | awk '{print tolower($0)}'; }
ucase() { echo "$*" | awk '{print toupper($0)}'; }

confirm() {
  is_set $force && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}
#TIP: use «confirm» for interactive confirmation before doing something
#TIP:> if ! confirm "Delete file"; then ; echo "skip deletion" ;   fi

ask() {
  # value=$(ask_question <question> <default>)
  # usage
  local answer
  read -r -p "$1 ($2): " answer
  echo "${answer:-$2}"
}

error_prefix="${col_red}>${col_reset}"
trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for
# trap 'echo ‘$BASH_COMMAND’ failed with error code $?' ERR
safe_exit() {
  [[ -n "$tmpfile" ]] && [[ -f "$tmpfile" ]] && rm "$tmpfile"
  trap - INT TERM EXIT
  log "$script_fname finished after $SECONDS seconds"
  exit 0
}

is_set() { [[ "$1" -gt 0 ]]; }
is_empty() { [[ -z "$1" ]]; }
is_not_empty() { [[ -n "$1" ]]; }
#TIP: use «is_empty» and «is_not_empty» to test for variables
#TIP:> if is_empty "$email" ; then ; echo "Need Email!" ; fi

is_file() { [[ -f "$1" ]]; }
is_dir() { [[ -d "$1" ]]; }
#TIP: use «is_file» and «is_dir» to test for files or folders
#TIP:> if is_file "/etc/hosts" ; then ; cat "/etc/hosts" ; fi

show_usage() {
  out "Program: ${col_grn}$script_fname $script_version${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$script_modified${col_reset}"

  echo -n "Usage: $script_fname"
  list_options |
    awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     } else {
          fulltext = fulltext sprintf("\n    %-10s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

show_tips() {
  grep <"$0" -v "\$0" |
    awk "
  /TIP: / {\$1=\"\"; gsub(/«/,\"$col_grn\"); gsub(/»/,\"$col_reset\"); print \"*\" \$0}
  /TIP:> / {\$1=\"\"; print \" $col_ylw\" \$0 \"$col_reset\"}
  "
}

init_options() {
  local init_command
  init_command=$(list_options |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3"=0; "}
    $1 ~ /flag/   && $5 != "" {print $3"="$5"; "}
    $1 ~ /option/ && $5 == "" {print $3"=\" \"; "}
    $1 ~ /option/ && $5 != "" {print $3"="$5"; "}
    ')
  if [[ -n "$init_command" ]]; then
    #log "init_options: $(echo "$init_command" | wc -l) options/flags initialised"
    eval "$init_command"
  fi
}

verify_programs() {
  os_uname=$(uname -s)
  os_version=$(uname -v)
  log "Running: on $os_uname ($os_version)"
  list_programs=$(echo "$*" | sort -u | tr "\n" " ")
  hash_programs=$(echo "$list_programs" | hash)
  verify_cache="$script_install_folder/.$script_name.$hash_programs.verified"
  if [[ -f "$verify_cache" ]]; then
    log "Verify : $list_programs (cached)"
  else
    log "Verify : $list_programs"
    programs_ok=1
    for prog in "$@"; do
      # shellcheck disable=SC2230
      if [[ -z $(which "$prog") ]]; then
        alert "$script_fname needs [$prog] but this program cannot be found on this $os_uname machine"
        programs_ok=0
      fi
    done
    if [[ $programs_ok -eq 1 ]]; then
      (
        echo "$script_name: check required programs OK"
        echo "$list_programs"
        date
      ) >"$verify_cache"
    fi
  fi
}

folder_prep() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      log "Create folder [$folder]"
      mkdir "$folder"
    else
      log "Cleanup: [$folder] - delete files older than $max_days day(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

expects_single_params() {
  list_options | grep 'param|1|' >/dev/null
}
expects_multi_param() {
  list_options | grep 'param|n|' >/dev/null
}

parse_options() {
  if [[ $# -eq 0 ]]; then

    show_usage >&2
    safe_exit
  fi

  ## first process all the -x --xxxx flags and options
  #set -x
  while true; do
    # flag <flag> is savec as $flag = 0/1
    # option <option> is saved as $option
    if [[ $# -eq 0 ]]; then
      ## all parameters processed
      break
    fi
    if [[ ! $1 == -?* ]]; then
      ## all flags/options processed
      break
    fi
    local save_option
    save_option=$(list_options |
      awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
    if [[ -n "$save_option" ]]; then
      if echo "$save_option" | grep shift >>/dev/null; then
        local save_var
        save_var=$(echo "$save_option" | cut -d= -f1)
        log "Found  : ${save_var}=$2"
      else
        log "Found  : $save_option"
      fi
      eval "$save_option"
    else
      die "cannot interpret option [$1]"
    fi
    shift
  done

  ((help)) && (
    echo "### USAGE"
    show_usage
    echo "### EXAMPLES"
    list_examples
    safe_exit
  )

  ## then run through the given parameters
  if expects_single_params; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    nb_singles=$(echo "$single_params" | wc -w)
    log "Expect : $nb_singles single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]] && die "need parameter [$param]"
      log "Found  : $param=$1"
      eval "$param=$1"
      shift
    done
  else
    log "No single params to process"
    single_params=""
    nb_singles=0
  fi

  if expects_multi_param; then
    #log "Process: multi param"
    nb_multis=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    log "Expect : $nb_multis multi parameter: $multi_param"
    [[ $nb_multis -gt 1 ]] && die "cannot have >1 'multi' parameter: [$multi_param]"
    [[ $nb_multis -gt 0 ]] && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]]; then
      log "Found  : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    log "No multi param to process"
    nb_multis=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
    log "all parameters have been processed"
  fi
}

tmpfile=""
logfile=""

initialize_script_data(){
    readonly thisday=$(date "+%Y-%m-%d")
    readonly thisyear=$(date "+%Y")

   if [[ -z $(dirname "$0") ]]; then
    # script called without path ; must be in $PATH somewhere
    # shellcheck disable=SC2230
    script_install_path=$(which "$0")
    if [[ -L "$script_install_path" ]] ; then
      script_install_path=$(readlink "$script_install_path") # when script was installed with e.g. basher
      script_install_folder=$(dirname "$script_install_path")
    fi
  else
    # script called with relative/absolute path
    script_install_folder=$(dirname "$0")
    script_install_folder=$(cd "$script_install_folder" && pwd)
    if [[ -n "$script_install_folder" ]] ; then
      script_install_path="$script_install_folder/$script_fname"
    else
      script_install_path="$0"
    fi
  fi
  log "Script binary: $script_install_path"
  log "Script folder: $script_install_folder"

  script_version=0.0.0
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  if git status >/dev/null; then
    readonly in_git_repo=1
  else
    readonly in_git_repo=0
  fi
}

prep_log_and_temp_dir() {
  if [[ -n "${tmpd:-}" ]]; then
    folder_prep "$tmpd" 1
    tmpfile=$(mktemp "$tmpd/$thisday.XXXXXX")
    log "Tmpfile: $tmpfile"
    # you can use this temporary file in your program
    # it will be deleted automatically when the program ends
  fi
  if [[ -n "${logd:-}" ]]; then
    folder_prep "$logd" 7
    logfile=$logd/$script_name.$thisday.log
    log "Logfile: $logfile"
    echo "$(date '+%H:%M:%S') | [$script_fname] $script_version started" >>"$logfile"
  fi
}

[[ $runasroot == 1 ]] && [[ $UID -ne 0 ]] && die "MUST be root to run this script"
[[ $runasroot == -1 ]] && [[ $UID -eq 0 ]] && die "CANNOT be root to run this script"

initialize_script_data
init_options
parse_options "$@"
prep_log_and_temp_dir
main
safe_exit
