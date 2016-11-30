#!/bin/bash

UBOOT_SPL_TIMEOUT=15s
UBOOT_IMG_TIMEOUT=60s
SERIAL_DEV=/dev/ttyUSB0
FILE_LOCATION=/tftpboot
TFTP_SERVER=192.168.1.187
TFTP_SUBFOLDER=
WS_PORT=8081
FW_IMAGE=wrfw_full.tar

while getopts "h?i:d:a:f:p:w:" opt; do
  case $opt in
    i)
      SERIAL_DEV=$OPTARG
      ;;
    d)
      FILE_LOCATION=$OPTARG
      ;;
    a)
      TFTP_SERVER=$OPTARG
      ;;
    f)
      TFTP_SUBFOLDER=$OPTARG
      ;;
    p)
      WS_PORT=$OPTARG
      ;;
    w)
      FW_IMAGE=$OPTARG
      ;;
    h|\?)
      echo "Usage: ./wr_init.sh [-i serial port] [-d file location] [-a tftp/ws server address]"
      echo "                    [-f tftp server subfolder] [-p ws server port] [-w fw image name]"
      echo "       Default serial port - /dev/ttyUSB0"
      echo "       Default u-boot file location - /tftpboot"
      echo "       Default tftp/ws server address - 192.168.1.110"
      echo "       Default tftp server subfolder - "
      echo "       Default ws server port - 8081"
      echo "       Default fw image name - wrfw_full.tar"
      exit 1
    ;;
    :)
      echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done

# Configure serial port
stty -F $SERIAL_DEV 115200 sane -echo -echok -echonl

echo "Sending $FILE_LOCATION/u-boot-spl.bin"
# Upload Secondary Program Loader (timeout 15 sec)
timeout $UBOOT_SPL_TIMEOUT sx -kb $FILE_LOCATION/u-boot-spl.bin < $SERIAL_DEV > $SERIAL_DEV
if [ $? != 0 ] ; then
    echo "Failed to upload u-boot-spl.bin!"
    echo "Reboot the board and try again!"
    exit 1
fi

# Upload u-boot image (timeout 60 sec)
echo "Sending $FILE_LOCATION/u-boot.img"
timeout $UBOOT_IMG_TIMEOUT sx -kb --ymodem $FILE_LOCATION/u-boot.img < $SERIAL_DEV > $SERIAL_DEV
if [ $? != 0 ] ; then
    echo "Failed to upload u-boot.img!"
    echo "Reboot the board and try again!"
    exit 1
fi

sleep 2s

stty -F $SERIAL_DEV 115200 sane -echo -echok -echonl

echo "Set environment"

# Set custom TFTP server address on target board
echo -ne "\nsetenv serverip $TFTP_SERVER\n" > $SERIAL_DEV

# Set custom TFTP server subfolder on target board
echo -ne "\nsetenv bootdir_tftp $TFTP_SUBFOLDER\n" > $SERIAL_DEV

# Set custom WEB Socket server port on target board
echo -ne "\nsetenv wsdstport $WS_PORT\n" > $SERIAL_DEV

# Set custom FW image filename
echo -ne "\nsetenv fwimage $TFTP_SUBFOLDER/$FW_IMAGE\n" > $SERIAL_DEV

# Save all new variables
echo -ne "\nsaveenv\n" > $SERIAL_DEV

# Get MAC address of WiRange board
cat < $SERIAL_DEV > ./mac &
echo -ne "\nprintenv ethaddr\n" > $SERIAL_DEV
sleep 1s
pkill -SIGINT -n cat
MACADDR=$(grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' -m 1 ./mac)

# Run board initialization procedure
echo -ne "\nrun production_init\n" > $SERIAL_DEV

echo "ethaddr=$MACADDR"

pkill cat
rm ./mac