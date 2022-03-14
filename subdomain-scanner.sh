#!/bin/bash
RED='\e[1;91m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[0;37m'
BCYAN='\033[1;36m'
YELLOW='\033[0;33m'
VER='0.1'
user=$(whoami)
date=$(date "+%D Time: %I:%M %p")

progress_bar()
{
  local DURATION=$1
  local INT=0.25      # refresh interval

  local TIME=0
  local CURLEN=0
  local SECS=0
  local FRACTION=0

  local FB=2588       # full block

  trap "echo -e $(tput cnorm); trap - SIGINT; return" SIGINT

  echo -ne "$(tput civis)\r$(tput el)│"                # clean line

  local START=$( date +%s%N )

  while [ $SECS -lt $DURATION ]; do
    local COLS=$( tput cols )

    # main bar
    local L=$( bc -l <<< "( ( $COLS - 5 ) * $TIME  ) / ($DURATION-$INT)" | awk '{ printf "%f", $0 }' )
    local N=$( bc -l <<< $L                                              | awk '{ printf "%d", $0 }' )

    [ $FRACTION -ne 0 ] && echo -ne "$( tput cub 1 )"  # erase partial block

    if [ $N -gt $CURLEN ]; then
      for i in $( seq 1 $(( N - CURLEN )) ); do
        echo -ne \\u$FB
      done
      CURLEN=$N
    fi

    # partial block adjustment
    FRACTION=$( bc -l <<< "( $L - $N ) * 8" | awk '{ printf "%.0f", $0 }' )

    if [ $FRACTION -ne 0 ]; then 
      local PB=$( printf %x $(( 0x258F - FRACTION + 1 )) )
      echo -ne \\u$PB
    fi

    # percentage progress
    local PROGRESS=$( bc -l <<< "( 100 * $TIME ) / ($DURATION-$INT)" | awk '{ printf "%.0f", $0 }' )
    echo -ne "$( tput sc )"                            # save pos
    echo -ne "\r$( tput cuf $(( COLS - 6 )) )"         # move cur
    echo -ne "│ $PROGRESS%"
    echo -ne "$( tput rc )"                            # restore pos

    TIME=$( bc -l <<< "$TIME + $INT" | awk '{ printf "%f", $0 }' )
    SECS=$( bc -l <<<  $TIME         | awk '{ printf "%d", $0 }' )

    # take into account loop execution time
    local END=$( date +%s%N )
    local DELTA=$( bc -l <<< "$INT - ( $END - $START )/1000000000" \
                   | awk '{ if ( $0 > 0 ) printf "%f", $0; else print "0" }' )
    sleep $DELTA
    START=$( date +%s%N )
  done

  echo $(tput cnorm)
  trap - SIGINT
}


mkdir_domain(){
    if [ ! -d ${domain} ];then
        mkdir ${domain}
    fi
}

wordlist(){
    curl -s https://raw.githubusercontent.com/dogukankurnaz/SecLists/master/Discovery/DNS/subdomains-top1million-5000.txt -o wordlist.txt
}

banner_frame() {
    msg="# $* #"
    edge=$(echo "$msg" | sed 's/./#/g')
    echo "$edge"
    echo "$msg"
    echo "$edge"
}



# Banner
banner(){
cat<<"EOF"
         _nnnn_                      
        dGGGGMMb     ,"""""""""""""""""""""""""""""""""".
       @p~qp~~qMb    |Subdomain && Zone Transfer Scanner|
       M|@||@) M|   _;..................................'
       @,----.JM| -'
      JS^\__/  qKL
     dZP        qKRb
    dZP          qKKb
   fZP            SMMb
   HZM            MMMM
   FqM            MMMM
 __| ".        |\dS"qML
 |    `.       | `' \Zq
_)      \.___.,|     .'
\____   )MMMMMM|   .'
     `-'       `--' dogukaN
EOF
echo ""
echo -e "${YELLOW}+ -- --=[Date: $date"
echo -e "${RED}+ -- --=[Welcome $user :)"
echo -e "${BLUE}+ -- --=[Subdomain / Transfer Zone Check v$VER by @dogukankurnaz"
echo -e "${PURPLE}+ -- --=[https://github.com/dogukankurnaz"
echo ""
}
banner
wordlist


# echo -e "${WHITE}1. Transfer Zone Scanner "
# echo -e "${WHITE}2. Subdomain Scanner "

banner_frame "1. Transfer Zone Scanner \ 2. Subdomain Scanner"




read -p "Your Choice = " -i Y input
if [[ $input == "1" ]]; then
    echo -e "${RED}+ -- --=[*] Usage : <domain name>  "
    read -p "Entry Domain =  " -i Y domain
    ns=$(dig +noall +answer NS $domain | awk '{print $5}')
    for server in $ns
    do
        dig @$server AXFR $domain >> axfrlist.txt 
    done
    echo -e "$(pwd)/axfrlist.txt file has been created in this directory."
elif [[ $input == "2"  ]]; then
    rm fullscan_subdomainlist.txt;rm fullscan_httpstatus.txt;rm fullscan_results.txt;rm fullscan_subdomainresults.txt
    touch fullscan_subdomainlist.txt;touch fullscan_httpstatus.txt;touch fullscan_curl.txt;touch fullscan_results.txt;touch fullscan_subdomainresults.txt
    echo -e "${WHITE}+ --------=[*] 1.UDP mode"
    echo -e "${WHITE}+ --------=[*] 2.Subdomains Over Databases (recommended mode) "
    echo -e "${WHITE}+ --------=[*] 3.FullScan mode (TCP it may take a long time)"
    
    read -p "Your Choice = " -i Y input
        if [[ $input == "1" ]]; then
        echo -e "${YELLOW}+ -- --=[*] Usage : <domain name>  "
        read -p "Entry Domain =  " -i Y domain
        mkdir_domain
        files=${domain} '/' ${domain}'_result.txt'
        echo -e "${YELLOW} [+] Subdomain Scan Started."
        progress_bar 1
        echo -e "${YELLOW} [+] Running in silent mode. If you want EXIT, press ctrl + z and check $(pwd)/${domain}/fast_results.txt in directory."
        for i in  $(cat wordlist.txt);
        do
            host -T $i.$domain | cat >> fast_subdomainlist.txt | $(curl -s -I --http2 http://$i.$domain >> fast_curl.txt | cut -d:  -f1 fast_curl.txt | cat fast_curl.txt | grep HTTP >> fast_httpstatus.txt   | paste fast_subdomainlist.txt fast_httpstatus.txt >> fast_subdomainresults.txt | cat fast_subdomainresults.txt | grep "HTTP" | cut -d ' ' -f1,4,5,6 | sort | uniq -c | sort -nr | sed -e 's/^[ \t]*//' >> fast_results.txt | mv fast_results.txt $(pwd)/${domain})        
        done        
        fi
        

        if [[ $input == "2" ]]; then
        echo -e "${YELLOW}+ -- --=[*] Usage : <domain name>  "
        read -p "Entry Domain =  " -i Y domain
        # mkdir_domain
        # files=${domain} '/' ${domain}'_result.txt'
        # progress_bar 1
        curl -s 'https://crt.sh/?q=%.'$domain'&output=json' | jq '.[] | {name_value}' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u |grep "name_value"|cut -d ' ' -f4 >> subdomain_database.txt 
        echo "[*]-----------------------Crt.sh OK"
        progress_bar 1
        curl -s "https://dns.bufferover.run/dns?q=."$domain | jq -r .FDNS_A[]|cut -d',' -f2|sort -u >> subdomain_database.txt
        echo "[*]----------------------- DNS BufferOver OK"
        progress_bar 1
        curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$domain/passive_dns" | grep -o -E "[a-zA-Z0-9._-]+\.$domain" >> subdomain_database.txt
        echo "[*]----------------------- AlienVault OK"
        progress_bar 1
        curl -s "https://urlscan.io/api/v1/search/?q=$domain" | grep -o -E "[a-zA-Z0-9._-]+\.$domain"  >> subdomain_database.txt       
        echo "[*]----------------------- URLSCAN OK"
        cat subdomain_database.txt | sort | uniq -c | sort -nr | sed -e 's/^[ \t]*//' > subdomain_database.txt
        progress_bar 1
        echo -e "${YELLOW} $(pwd)/${domain}/subdomain_database.txt in directory."        
        fi        
    
        if [[ $input == "3" ]]; then
            echo -e "${PURPLE}+ -- --=[*] Usage : <domain name>  "
            read -p "Entry Domain =  " -i Y domain
            mkdir_domain
            files=${domain} '/'${domain}'_result.txt'
            echo -e "${WHITE}$(pwd)/${domain}/results.txt file has been created in this directory. If you want EXIT, press ctrl + z"
            echo -e "${BCYAN} [+] Subdomain Scan Started."
            progress_bar 1
            echo -e "${BCYAN} [+] Running in silent mode. If you want EXIT, press ctrl + z and check results.txt in directory."
            for i in  $(cat wordlist.txt);
            do
                host $i.$domain | cat >> fullscan_subdomainlist.txt |$(curl -s -I --http2 http://$i.$domain >> fullscan_curl.txt | cut -d:  -f1 fullscan_curl.txt | cat fullscan_curl.txt | grep HTTP >> fullscan_httpstatus.txt   | paste fullscan_subdomainlist.txt fullscan_httpstatus.txt >> fullscan_subdomainresults.txt | cat fullscan_subdomainresults.txt | grep "HTTP" | cut -d ' ' -f1,4,5,6 | sort | uniq -c | sort -nr | sed -e 's/^[ \t]*//' >> fullscan_results.txt |  mv fullscan_results.txt $(pwd)/${domain} )
            done
        fi       
fi
