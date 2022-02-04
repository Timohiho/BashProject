declare -ia board    # array keeps track of board status
declare -i pieces    # number of pieces on board
declare -i score=0   # score
declare -i flag_skip # flag to prevent multiple actions on same frame
declare -i moves     # possible moves, if 0 player lost
declare ESC=$'\e'    # escape byte

declare -i board_size=4 # Board size
declare -i target=2048  # Target of the game


declare -a colors
colors[2]=33             # yellow text
colors[4]=32             # green text
colors[8]=34             # blue text
colors[16]=36            # cyan text
colors[32]=35            # purple text
colors[64]="33m\033[7"   # yellow background
colors[128]="32m\033[7"  # green background
colors[256]="34m\033[7"  # blue background
colors[512]="36m\033[7"  # cyan background
colors[1024]="35m\033[7" # purple background
colors[2048]="31m\033[7" # red background (won with default target)

function _seq {
  local cur=1
  local max
  local inc=1
  case $# in
    1) let max=$1;;
    2) let cur=$1
       let max=$2;;
    3) let cur=$1
       let inc=$2
       let max=$3;;
  esac
  while test $max -ge $cur; do
    printf "$cur "
    let cur+=inc
  done
}

# print currect status of the game, last added piece is marked red
function print_board {
  clear
  printf "$header pieces=$pieces target=$target score=$score\n" # Print info about current game status
  printf "\n"
  printf '/------'
  for l in $(_seq 1 $index_max); do
    printf '+------'
  done
  printf '\\\n'
  for l in $(_seq 0 $index_max); do
    printf '|'
    for m in $(_seq 0 $index_max); do
      if let $ {board[l*$board_size+m]}; then
        if let '(last_added==(l*board_size+m))|(first_round==(l*board_size+m))'; then
          printf '\033[1m\033[31m %4d \033[0m|' ${board[l*$board_size+m]} # (last added piece) print red
        else
          printf "\033[1m\033[${colors[${board[l*$board_size+m]}]}m %4d\033[0m |" ${board[l*$board_size+m]} # Print normal
        fi
      else
        printf '      |'
      fi
    done
    let l==$index_max || {
      printf '\n|------'
      for l in $(_seq 1 $index_max); do
        printf '+------'
      done
      printf '|\n'
    }
  done
  printf '\n\\------'
  for l in $(_seq 1 $index_max); do
    printf '+------'
  done
  printf '/\n'
}

function generate_piece {
  while true; do
    let pos=RANDOM%fields_total
    let board[$pos] || {
      let value=RANDOM%10?2:4
      board[$pos]=$value
      last_added=$pos
      break;
    }
  done
  let pieces++
}

function push_pieces {
  case $4 in
    "up")
      let "first=$2*$board_size+$1"
      let "second=($2+$3)*$board_size+$1"
      ;;
    "down")
      let "first=(index_max-$2)*$board_size+$1"
      let "second=(index_max-$2-$3)*$board_size+$1"
      ;;
    "left")
      let "first=$1*$board_size+$2"
      let "second=$1*$board_size+($2+$3)"
      ;;
    "right")
      let "first=$1*$board_size+(index_max-$2)"
      let "second=$1*$board_size+(index_max-$2-$3)"
      ;;
  esac
  let ${board[$first]} || {
    let ${board[$second]} && {
      if test -z $5; then
        board[$first]=${board[$second]}
        let board[$second]=0
        let change=1
      else
        let moves++
      fi
      return
    }
    return
  }
  let ${board[$second]} && let flag_skip=1
  let "${board[$first]}==${board[second]}" && {
    if test -z $5; then
      let board[$first]*=2
      let "board[$first]==$target" && end_game 1
      let board[$second]=0
      let pieces-=1
      let change=1
      let score+=${board[$first]}
    else
      let moves++
    fi
  }
}

function apply_push {
  for i in $(_seq 0 $index_max); do
    for j in $(_seq 0 $index_max); do
      flag_skip=0
      let increment_max=index_max-j
      for k in $(_seq 1 $increment_max); do
        let flag_skip && break
        push_pieces $i $j $k $1 $2
      done
    done
  done
}

function check_moves {
  let moves=0
  apply_push up fake
  apply_push down fake
  apply_push left fake
  apply_push right fake
}

function key_react {
  let change=0
  read -d '' -sn 1
  test "$REPLY" = "$ESC" && {
    read -d '' -sn 1 -t1
    test "$REPLY" = "[" && {
      read -d '' -sn 1 -t1
      case $REPLY in
        # arrow keys
        A) apply_push up;;
        B) apply_push down;;
        C) apply_push right;;
        D) apply_push left;;
      esac
    }
  } || {
    case $REPLY in
      # ijkl keys
      i) apply_push up;;
      j) apply_push left;;
      k) apply_push down;;
      l) apply_push right;;

      # wasd keys
      w) apply_push up;;
      a) apply_push left;;
      s) apply_push down;;
      d) apply_push right;;
    esac
  }
}

function end_game {

  print_board # Print final board
  printf "Your score: $score\n" # print score

  stty echo
  let $1 && {
    printf "Congratulations you have achieved $target\n" # Print if won
    exit 0
  }
  printf "\nYou have lost, better luck next time.\033[0m\n" # print if lost
  exit 0
}


#init board
let fields_total=board_size*board_size # Total amount of positions
let index_max=board_size-1 # max index of board array
for i in $(_seq 0 $fields_total); do board[$i]="0"; done # fill board with empty
let pieces=0
generate_piece
first_round=$last_added
generate_piece


while true; do
  print_board
  key_react
  let change && generate_piece
  first_round=-1
  let pieces==fields_total && {
   check_moves
   let moves==0 && end_game 0 #lose the game
  }
done