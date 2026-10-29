#!/data/data/com.termux/files/usr/bin/bash
read -r title
read -r content
title="${title:-Antigravity}"
content="${content:-Attention needed}"
termux-notification --id "agy-attention" --title "$title" --content "$content" --priority high
