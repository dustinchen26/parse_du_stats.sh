##################################
#Author:Dustin_Chen2024.01.05
##################################

#!/bin/bash

# Function to parse GNB DU Statistics line
parseGNBLine() {
    local line="$1"
    echo -e "\n$line"
}

# Function to calculate DL and UL BLER
calculateDLandULbler() {
    local ack_tb0="$1"
    local nack_tb0="$2"
    local ulCRCsucces="$3"
    local ulCRCfail="$4"

    local dlBler="0.0000"
    local ulBler="0.0000"

    # Check if the denominator is not zero before calculating DL BLER
    if ((ack_tb0 + nack_tb0 != 0)); then
        dlBler=$(awk "BEGIN {printf \"%.4f\", $nack_tb0 / ($ack_tb0 + $nack_tb0)}")
    fi

    # Check if the denominator is not zero before calculating UL BLER
    if ((ulCRCsucces + ulCRCfail != 0)); then
        ulBler=$(awk "BEGIN {printf \"%.4f\", $ulCRCfail / ($ulCRCsucces + $ulCRCfail)}")
    fi

    echo "UE-ID=$ueId dlbler=$dlBler ulbler=$ulBler"
}

# Function to parse throughput data
parseTput() {
    local line="$1"
    local values=($line)
    local ueId=${values[0]}
    local dlTput=${values[5]}
    local ulTput=${values[7]}
    
    # Check if both DL-Throughput and UL-Throughput are not empty, then output
    if [[ -n $dlTput && -n $ulTput ]]; then
        echo "UE-ID=$ueId DL-Throughput=$dlTput UL-Throughput=$ulTput"
    fi

    # Continue parsing subsequent lines with numbers, empty lines, or lines starting with dashes
    while read -r nextLine && [[ $nextLine =~ ^[0-9]*$|^$ || ! $nextLine =~ ^--------------------------------------------------------------------------------------------- ]]; do
        # Skip empty lines
        if [[ -z $nextLine ]]; then
            continue
        fi

        values=($nextLine)
        local ueId=${values[0]}
        local dlTput=${values[5]}
        local ulTput=${values[7]}
        
        # Check if both DL-Throughput and UL-Throughput are not empty, then output
        if [[ -n $dlTput && -n $ulTput ]]; then
            echo "UE-ID=$ueId DL-Throughput=$dlTput UL-Throughput=$ulTput"
        fi
    done
}

# Function to parse UE data
parseUEData() {
    local line="$1"
    local values=($line)
    local ueId=${values[0]}
    local ack_tb0=${values[5]}
    local nack_tb0=${values[6]}
    local ulCRCsucces=${values[18]}
    local ulCRCfail=${values[19]}

    #echo "UE-ID=$ueId DL-TX=$ack_tb0 DL-RETX=$nack_tb0 UL-CRC-SUCC=$ulCRCsucces UL-CRC-FAIL=$ulCRCfail"
    calculateDLandULbler "$ack_tb0" "$nack_tb0" "$ulCRCsucces" "$ulCRCfail"

    # Continue parsing subsequent lines with numbers
    while IFS= read -r nextLine && [[ $nextLine =~ ^[0-9] ]]; do
        values=($nextLine)
        ueId=${values[0]}
        ack_tb0=${values[5]}
        nack_tb0=${values[6]}
        ulCRCsucces=${values[18]}
        ulCRCfail=${values[19]}

        #echo "UE-ID=$ueId DL-TX=$ack_tb0 DL-RETX=$nack_tb0 UL-CRC-SUCC=$ulCRCsucces UL-CRC-FAIL=$ulCRCfail"
        calculateDLandULbler "$ack_tb0" "$nack_tb0" "$ulCRCsucces" "$ulCRCfail"
    done
}

# Main script
for file in du_stats_*; do
    echo "Processing file: $file"

    # Read the entire file into a loop
    while IFS= read -r line; do
        # Remove carriage return character if present and trim leading/trailing spaces
        line=$(echo "$line" | tr -d '\r' | sed 's/^ *//;s/ *$//')

        if [[ $line == *"GNB DU Statistics  "* ]]; then
            parseGNBLine "$line"
        elif [[ $line == *"UE-ID     BEAM-ID   CSIRS-PORT"* ]]; then
            # Check if the next line has numbers
            read -r nextLine
            [[ $nextLine =~ ^[0-9] ]] && parseTput "$nextLine"
        elif [[ $line == *"UE-ID   CELL-ID   ON-SUL"* ]]; then
            # Check if the next line has numbers
            read -r nextLine
            [[ $nextLine =~ ^[0-9] ]] && parseUEData "$nextLine"
        fi
    done < "$file"  # Read content from the file

    echo "Finished processing file: $file"
done | tee output.txt  # Output both to console and file
