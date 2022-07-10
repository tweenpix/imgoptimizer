#!/bin/bash

#### APEXWEB.RU
#### command line for start
#### run from parrent image directory
#find . -type d \( ! -name . \) -exec bash -c "cd '{}' && pwd && /home/backup/imagecompress.sh" \;

#convert from bmp to jpg
find . -maxdepth 1 -iname '*bmp' -type f -exec bash -c "mogrify -format jpg {} && chown www-data:www-data {}" \;

#svgo
find . -maxdepth 1 -iname '*svg' -type f -exec bash -c "svgo {} && chown www-data:www-data {}" \;

#webp and avif
for current in $(find . -maxdepth 1 \( -iname '*.jpeg' -o -iname '*.jpg' -o -iname '*.png' \) -type f); do
	if [ ! -f $current.webp ]; then
		echo 'need create webp from '$current
		cp $current $current.webp
		squoosh-cli --webp '{"quality":85, "method":4,"sns_strength":50,"filter_strength":60,"filter_type":1,"segments":4,"pass":1,"show_compressed":0,"preprocessing":0, "autofilter":0, "partition_limit":0, "alpha_compression":1, "alpha_filtering":1, "alpha_quality":100,"lossless":0}' $current.webp
		chown www-data:www-data $current.webp
	fi
	if [ ! -f $current.avif ]; then
		echo 'need create avif from '$current
		cp $current $current.avif
		squoosh-cli --avif '{"speed":2}' $current.avif
		chown www-data:www-data $current.avif
	fi
done

#mozjpeg
for currentjpeg in $(find . -maxdepth 1 \( -iname '*.jpeg' -o -iname '*.jpg' \) -type f); do
	echo $currentjpeg" is "$(identify -format %c $currentjpeg)
	if [[ $(identify -format %c $currentjpeg) != *optimised* ]]; then
		squoosh-cli --mozjpeg '{"quality":85, "baseline":false, "arithmetic":false, "progressive":true, "op timize_coding":true, "smoothing":0,"color_space":3, "quant_table":3, "trellis_multipass":false, "trel lis_opt_zero":false, "trellis_opt_table":false, "trellis_loops":1,"auto_subsample":true, "chroma_sub sample":2, "separate_chroma_quality":false, "chroma_quality":75 }' $currentjpeg
		mogrify -set comment "optimised" $currentjpeg
		chown www-data:www-data $currentjpeg
	fi
done

#oxipng
for currentpng in $(find . -maxdepth 1 -iname '*.png' -type f); do
	echo $currentpng" is "$(identify -format %[comment] $currentpng)
	if [[ $(identify -format %[comment] $currentpng) != *optimised* ]]; then
		squoosh-cli --oxipng '{"level":6}' $currentpng
		mogrify -set comment "optimised" $currentpng
		chown www-data:www-data $currentpng
	fi
done
