##################################
# Author: Dustin_Chen 2024.08.20
##################################

#!/bin/bash

# Switch to the directory /var/log/du/
#cd /var/log/du/ || { echo "Failed to change directory to /var/log/du/"; exit 1; }

# Function to parse GNB DU Statistics line
parseGNBLine() {
    local line="$1"

    # Remove leading spaces from lines that match the specific patterns
    if [[ $line == *"EGTP DL Tpt"* || $line == *"X2 EGTP DL Tpt"* || $line == *"SCH  DL Tpt"* ]]; then
        line=$(echo "$line" | sed 's/^[ \t]*//')  # Remove all leading spaces and tabs
    fi

    echo "$line"
}

# Calculate DL BLER and UL BLER
calculateDLandULbler() {
    local ack_tb0="$1"
    local nack_tb0="$2"
    local ulCRCsucces="$3"
    local ulCRCfail="$4"

    local dlBler="0.0000"
    local ulBler="0.0000"

    # Check if the denominator is not zero before calculating DL BLER
    if [[ $(($ack_tb0 + $nack_tb0)) -ne 0 ]]; then
        dlBler=$(awk "BEGIN {printf \"%.4f\", $nack_tb0 / ($ack_tb0 + $nack_tb0)}")
    fi

    # Check if the denominator is not zero before calculating UL BLER
    if [[ $(($ulCRCsucces + $ulCRCfail)) -ne 0 ]]; then
        ulBler=$(awk "BEGIN {printf \"%.4f\", $ulCRCfail / ($ulCRCsucces + $ulCRCfail)}")
    fi

    echo "UE-ID=$ueId dlbler=$dlBler ulbler=$ulBler"
}

parseTput() {
    local line="$1"
    local values=($line)
    local ueId=${values[0]}
    local dlTput=${values[5]}
    local ulTput=${values[7]}
    
    # Check if DL-Throughput and UL-Throughput are empty, if not, output
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

        # Check if DL-Throughput and UL-Throughput are empty, if not, output
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
    while read -r nextLine && [[ $nextLine =~ ^[0-9] ]]; do
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
    file_path=$(realpath "$file")
    echo "Processing file: $file_path"

    # Find the line number of the last "GNB DU Statistics" line
    lastGNBStatisticsLine=$(grep -nE "GNB DU Statistics\s+[A-Za-z]{3} [A-Za-z]{3} [ ]?[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}" "$file" | cut -d: -f1 | tail -n 1)
    echo "Last GNB Statistics Line: $lastGNBStatisticsLine"

    if [[ -n $lastGNBStatisticsLine ]]; then
        # Process lines starting from the last "GNB DU Statistics" line
        tail -n +"$lastGNBStatisticsLine" "$file" | while IFS= read -r line; do
            line=$(echo "$line" | tr -d '\r')  # Remove carriage return character if present
            line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')  # Trim leading and trailing spaces/tabs

            #echo "Processing line: $line"

            # Parse the line if it's not empty
            if [[ -n $line ]]; then
                if [[ $line == *"GNB DU Statistics  "* ]]; then
                    parseGNBLine "$line"

                elif [[ $line == *"UE-ID     BEAM-ID   CSIRS-PORT"* ]]; then
                    # Check if the next line has numbers
                    read -r nextLine
                    if [[ $nextLine =~ ^[0-9] ]]; then
                        parseTput "$nextLine"
                    fi    
                    
                elif [[ $line == *"EGTP DL Tpt"* || $line == *"X2 EGTP DL Tpt"* || $line == *"SCH  DL Tpt"* ]]; then
                    parseGNBLine "$line"                        
                                
                elif [[ $line == *"UE-ID   CELL-ID   ON-SUL"* ]]; then
                    # Check if the next line has numbers
                    read -r nextLine
                    if [[ $nextLine =~ ^[0-9] ]]; then
                        parseUEData "$nextLine"
                    fi
                fi
            fi
        done
    fi

    echo "Finished processing file: $file_path"
done
