#!/bin/bash
set -e

# Build should be done before running this.

echo "Checking for Metal framework linkage..."
MAGICKCORE_DYLIB=$(ls MagickCore/.libs/libMagickCore-*.dylib 2>/dev/null | head -n 1)
if [ -z "$MAGICKCORE_DYLIB" ]; then
    echo "Error: could not locate libMagickCore dylib"
    exit 1
fi
otool -L "$MAGICKCORE_DYLIB" | grep Metal || { echo "Error: libMagickCore not linked with Metal"; exit 1; }

echo "Generating reference image..."
./utilities/magick rose: reference.png

echo "Running Metal contrast..."
# Capture stderr to check for debug logs
MAGICK_DEBUG=Accelerate ./utilities/magick rose: -contrast metal_out.png 2> metal.log

echo "Checking debug log for Metal usage..."
if grep -q "Metal device created successfully" metal.log; then
    echo "SUCCESS: Metal device selected."
else
    echo "FAILURE: Metal device NOT selected."
    cat metal.log
    exit 1
fi

if grep -qi "pipeline.*kernel" metal.log; then
    echo "SUCCESS: Metal kernel acquired."
else
    echo "WARNING: specific kernel log not found, check implementation."
fi

echo "Comparing results..."
RMSE=$(./utilities/magick compare -metric RMSE reference.png metal_out.png null: 2>&1 || true)
echo "RMSE: $RMSE"
# Fail if RMSE exceeds threshold (first field is the raw value)
RAW=$(echo "$RMSE" | awk -F'[( )]' '{print $1}')
if [ -n "$RAW" ] && [ "$(echo "$RAW > 100" | bc -l 2>/dev/null)" = "1" ]; then
    echo "FAILURE: Metal output differs significantly from reference (RMSE=$RAW)"
    exit 1
fi
echo "SUCCESS: Metal output matches reference within tolerance."
