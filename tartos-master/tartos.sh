#!/bin/bash
#help
helpme="
*******TAR to shell script (tartos)********
***Usage: 
tartos archive script \"commands\" -o outdir
tartos archive script \"commands\"
tartos archive script
tartos archive
tartos
tartos -o outdir archive script \"commands\"
tartos archive -o outdir script
tartos archive script -o outdir \"commands\"
tartos -o outdir
***etc...

***outdir can be specified without -o too
***but then all the inputs must be given:
tartos archive script \"commands\" outdir

***archive is the tar archive name/path
***script is the script path/name to be
***commands are custom commands to be run when executing the resultant script
***outdir is the directory where the resultant script will install/put the
***archive contents, it's default at the working directory

***tartos -h or tartos --help to show this help menu
***Consult man page for more info\n"
#help


#argument analysis
args=( "${@}" )
ind=0
cont=0
for arg in "${args[@]}"; do

[ "$arg" == "-h" ] || [ "$arg" == "--help" ] && printf "$helpme" && exit 0

if [[ "$arg" == -[Oo] ]] || [[ $cont == 1 ]]; then
[[ $cont > 1 ]] && echo "Invalid use of -o or-O option, you can't use it more than once"
inarg[3]="$arg"
#echo "$ind ${inarg[((ind))]} ${inarg[3]}"
((cont++))
continue
fi
inarg[((ind))]="$arg"
#echo "$ind ${inarg[((ind))]} ${inarg[((ind))]} ${inarg[3]}"
((ind++))
done
[ "${args[4]}" != "" ] && echo "Too many arguments, stop...
If you are using commands as arguments,
try putting them in double quotes and thus constructing
a single argument altogether
***Enter tartos -h or tartos --help to get help" && exit 0
#argument analysis
#Checking if destination directory exists
dest="${inarg[3]}"
[[ "$dest" == "" ]] && dest="./" || mkdir -p "$dest"
[ ! -d "$dest" ] && echo "Invalid output directory, using default..." && inarg[3]="./"

#first argument is the archive
payload="${inarg[0]}"
#second argument is the script name
script="${inarg[1]}"
#third argument is custom command or script
custi="${inarg[2]}"

#pay=`cat $payload`
#Creating temporary file

tmp=__extract__$RANDOM

#Supported archives
extention=(".tar.lzo" ".tar.lz" ".tar.lzma" ".tar.xz" ".tar.gz" ".tar.bz2" 
#Don't edit the line below, add extentions above, add from left/begining
 #.tar must be the last element
".tar")

#format must be sequential
format=("--lzop" "--lzip" "--lzma" "-J" "-z" "-j" "")


#echo ${extention[((index))]}
while true
do
if [ ! -f "$payload" ]; then
read -e -p "Enter the path of the tar archive: " payload
else
echo -e "Found: $payload"
break
fi
done

index=0;

for i in ${extention[@]}; do
[ "$payload" == *"$i" ]  && break
((index++))
done

if [[ $index -eq ${#extention[@]} ]]; then
echo -e "FAILD!!!\nArchive type not supported...!!!
Try extracting the content and compressing it to a supported tar archive,
then run it again.

Supported tars:

${extention[@]}\n"
exit 0
fi

while true
do
[ "$script" != "" ] || read -e -p "Enter the name/path of the script: " script
[ "$script" == "" ] || break
done
[ "$custi" != "" ] || read -e -p "Enter custom command or script (if any): " custi

[ "$dest" == "./" ] && echo "Bound directory: Working directory" || echo "Bound directory: $dest"

printf "#!/bin/bash
PAYLOAD_LINE=\`awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0; }' \$0\`
tail -n+\$PAYLOAD_LINE \$0 | tar -xv ${format[((index))]} -C $dest
#This is the place to add custom command
echo -e '\nExecuting custom commands....\n'
$custi
exit 0
__PAYLOAD_BELOW__\n" > "$tmp" &&

cat "$tmp" "$payload" > "$script" && rm "$tmp" &&
chmod +x "$script" &&
echo -e "***Success*** \nScript is saved as: $script" || 
echo -e "Failed!!!\nSomething seriously went wrong..."

