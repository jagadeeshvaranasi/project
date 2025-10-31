#!/bin/bash
set -e

# ====== Update system ======
sudo apt update -y && sudo apt upgrade -y

# ====== Install Maven ======
sudo apt install maven -y
sudo apt install python3.10-venv -y
