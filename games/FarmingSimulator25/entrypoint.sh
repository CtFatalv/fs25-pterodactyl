#!/bin/bash
cd /home/container

# Information output
echo "Running on Debian $(cat /etc/debian_version)"
echo "Current timezone: $(cat /etc/timezone)"
wine --version

# Make internal Docker IP address available to processes.
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

if [[ $XVFB == 1 ]]; then
        Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} &
fi

# Configure Wine for 32-bit
export WINEARCH=win32
export WINEPREFIX=/home/container/.wine

# Initialize the 32-bit Wine prefix
mkdir -p $WINEPREFIX
wineboot --init

# Install Wine Gecko if required
if [[ $WINETRICKS_RUN =~ gecko ]]; then
        echo "Installing Gecko for 32-bit Wine prefix"
        WINETRICKS_RUN=${WINETRICKS_RUN/gecko}

        if [ ! -f "$WINEPREFIX/gecko_x86.msi" ]; then
                wget -q -O $WINEPREFIX/gecko_x86.msi http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86.msi
        fi

        wine msiexec /i $WINEPREFIX/gecko_x86.msi /qn /quiet /norestart /log $WINEPREFIX/gecko_x86_install.log
fi

# Install Wine Mono if required
if [[ $WINETRICKS_RUN =~ mono ]]; then
        echo "Installing Mono for 32-bit Wine prefix"
        WINETRICKS_RUN=${WINETRICKS_RUN/mono}

        if [ ! -f "$WINEPREFIX/mono.msi" ]; then
                wget -q -O $WINEPREFIX/mono.msi https://dl.winehq.org/wine/wine-mono/9.3.0/wine-mono-9.3.0-x86.msi
        fi

        wine msiexec /i $WINEPREFIX/mono.msi /qn /quiet /norestart /log $WINEPREFIX/mono_install.log
fi

# Install other packages using winetricks
for trick in $WINETRICKS_RUN; do
        echo "Installing $trick in 32-bit Wine prefix"
        winetricks -q $trick
done

# Remove temporary files for Nginx
rm -rf /home/container/.nginx/tmp/*

# Start Nginx
echo "⟳ Starting Nginx..."
nginx -c /home/container/.nginx/nginx/nginx.conf -p /home/container/.nginx/
echo "✓ started Nginx..."

# Replace Startup Variables
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

# Run the server in 32-bit mode
export WINEARCH=win32
export WINEPREFIX=/home/container/.wine
eval ${MODIFIED_STARTUP}
