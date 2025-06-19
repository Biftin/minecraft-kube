#!/bin/sh

# Logging function that outputs to stderr
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

accept_eula() {
  log "Checking EULA agreement"
  
  # Check if eula.txt exists and contains eula=true
  if [ -f /data/eula.txt ]; then
    if grep -q "^eula=true" /data/eula.txt; then
      log "EULA already accepted"
      return 0
    else
      log "EULA not accepted, updating eula.txt"
    fi
  else
    log "eula.txt not found, creating it"
  fi
  
  # Write eula=true to eula.txt
  echo "eula=true" > /data/eula.txt
  log "EULA accepted"
}

ensure_rcon() {
  log "Configuring RCON settings"

  # ensure rcon is enabled in server.properties (enable-rcon=true)
  if ! grep -q "^enable-rcon=true" /data/server.properties; then
    echo "enable-rcon=true" >> /data/server.properties
    log "RCON enabled in server.properties"
  else
    log "RCON is already enabled in server.properties"
  fi
  
  if [ -z "$RCON_PASSWORD" ]; then
    log "ERROR: RCON_PASSWORD is not set. Please set it to a secure value."
    exit 1
  fi

  log "RCON_PASSWORD is set, configuring server.properties"
  
  # ensure the password is written to the minecraft server properties
  if ! grep -q "^rcon.password=" /data/server.properties; then
    echo "rcon.password=$RCON_PASSWORD" >> /data/server.properties
    log "RCON password set in server.properties"
  else
    # overwrite the existing password
    sed -i "s/^rcon.password=.*/rcon.password=$RCON_PASSWORD/" /data/server.properties
    log "RCON password updated in server.properties"
  fi
}

configure_java_memory() {
  log "Configuring Java memory settings based on container limits"
  
  # set java memory percentage (-XX:MaxRamPercentage, -XX:MinRamPercentage) based on container memory limit
  # if the container memory limit is < 2GiB, use 25% as maximum and minimum
  # if the container memory limit is >= 2GiB, use 75% as maximum and 50% as minimum

  # Get container memory limit in bytes
  MEMORY_LIMIT=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "0")
  log "Detected memory limit: $MEMORY_LIMIT bytes"

  # Convert 2GiB to bytes (2 * 1024 * 1024 * 1024)
  TWO_GIB=2147483648

  if [ "$MEMORY_LIMIT" -lt "$TWO_GIB" ] || [ "$MEMORY_LIMIT" = "0" ]; then
      # Less than 2GiB or no limit detected
      log "Using conservative memory settings (25% max/min) for limited memory environment"
      echo "-XX:MaxRAMPercentage=25 -XX:MinRAMPercentage=25"
  else
      # 2GiB or more
      log "Using optimized memory settings (75% max, 50% min) for high memory environment"
      echo "-XX:MaxRAMPercentage=75 -XX:MinRAMPercentage=50"
  fi
}

DEFAULT_JAVA_FLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=mcflags.emc.gs -Dcom.mojang.eula.agree=true"

determine_java_flags() {
  # Check if the user has set custom JAVA_FLAGS
  if [ -n "$JAVA_FLAGS" ]; then
    log "Using custom JAVA_FLAGS provided by user"
    echo "$JAVA_FLAGS"
  else
    log "Using default optimized Java flags"
    echo "$DEFAULT_JAVA_FLAGS"
  fi
}

JAVA_CMD="java $(configure_java_memory) $(determine_java_flags)"

accept_eula
ensure_rcon
exec $JAVA_CMD -jar /app/server.jar nogui "$@"
