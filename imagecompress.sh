#!/bin/bash
export NODE_OPTIONS='--no-experimental-fetch'
# APEXWEB.RU
# command line for start
# run from parent image directory

set -e
set -u
set -o pipefail
LC_ALL=C.UTF-8

LYELLOW='\033[1;33m'
DBOLD='\033[2m'

hour=$(date +%H)

# Определение пути к лог-файлу
log_file="/var/log/optimization.log"

echo "режим работы скрипта с 22 до 6 утра и с 6 до 9 утра"

if [ "$hour" -ge 06 ] && [ "$hour" -lt 09 ]; then
    exit 0
fi

if [ "$hour" == 06 ] || [ "$hour" == 09 ]; then
    echo "Скрипт работает в режиме тестирования"
fi

if [ "$hour" == 06 ] || [ "$hour" == 22 ]; then
    echo "Скрипт запущен в $hour часов"
    echo "Начало оптимизации изображений"
fi

if ! command -v identify >/dev/null || ! command -v mogrify >/dev/null || ! command -v svgo >/dev/null || ! command -v squoosh-cli >/dev/null; then
    echo "need install ImageMagick, SVGO (node js packet), Squoosh-cli (node js packet)"
    exit 1
fi

cleanup_optimised_files() {
    local log_file=$1
    echo "Cleaning up optimised files"
    local count=0
    for file in *.optimised; do
        if [ -f "$file" ]; then
            rm -- "${file}"
            count=$((count + 1))
        fi
    done
    echo "Removed $count optimised files" >>"$log_file"
}

handle_parameters() {
    local log_file=$1
    local clean_param=$2
    if [ "$clean_param" == "clean" ]; then
        cleanup_optimised_files "$log_file"
        exit 0
    fi
}

# Обработка параметров запуска скрипта
if [ $# -gt 0 ]; then
    handle_parameters "$log_file" "$1"
fi
# Логирование начала работы скрипта
echo "Начало работы скрипта в $(date)" >>"$log_file"

for bmp_file in *.bmp; do
    if [[ -f "$bmp_file" && ! -f "$bmp_file.optimised" ]]; then

            if [[ "$bmp_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
                echo "73 Skipping $bmp_file due to invalid characters in filename" >>"$log_file"
            else
                echo "Converting $bmp_file to jpg"
                mogrify -format jpg "$bmp_file"
                chown www-data:www-data "$bmp_file.jpg"
                touch "$bmp_file.optimised"

            fi
    fi
done

##svg optimized
for svg_file in *.svg; do
    if [[ -f "$svg_file" && ! -f "$svg_file.optimised" ]]; then

            if [[ "$svg_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
                echo "89 Skipping $svg_file due to invalid characters in filename" >>"$log_file"
            else
                echo "Optimizing $svg_file" >>"$log_file"
                svgo "$svg_file"
                chown www-data:www-data "$svg_file"
                touch "$svg_file.optimised"
            fi

    fi
done

for image_file in *.jpeg *.jpg *.png; do
    if [[ -f "$image_file" && ! -f "$image_file.optimised" ]]; then
        if [[ "$image_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
            echo "103 Skipping $image_file due to invalid characters in filename" >>"$log_file"
        else
            echo "Optimizing $image_file" >>"$log_file"

                if [ ! -f "${image_file}.webp" ]; then
                    echo -e "${LYELLOW}need create ${DBOLD}webp from $image_file"
                    # tput sgr0
                    cp -- "$image_file" "${image_file}.webp"
                    squoosh-cli --webp '{"quality":85, "method":4,"sns_strength":50,"filter_strength":60,"filter_type":1,"segments":4,"pass":1,"show_compressed":0,"preprocessing":0, "autofilter":0, "partition_limit":0, "alpha_compression":1, "alpha_filtering":1, "alpha_quality":100,"lossless":0}' "${image_file}.webp"
                    chown www-data:www-data "${image_file}.webp"
                fi
                if [ ! -f "${image_file}.avif" ]; then
                    echo -e "${LYELLOW}need create ${DBOLD}avif from $image_file"
                    # tput sgr0
                    cp -- "$image_file" "${image_file}.avif"
                    squoosh-cli --avif '{"speed":2}' "${image_file}.avif"
                    chown www-data:www-data "${image_file}.avif"
                fi

        fi
    fi
done

for jpeg_file in *.jpeg *.jpg; do
        if [[ -f "$jpeg_file" && ! -f "$jpeg_file.optimised" ]]; then

        if [[ "$jpeg_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
            echo "130 Skipping $jpeg_file due to invalid characters in filename" >>"$log_file"
        else
        echo "Optimizing $jpeg_file" >>"$log_file"
            if [[ $(identify -format %c "$jpeg_file") != *optimised* ]]; then
                echo "Optimizing $jpeg_file"
                squoosh-cli --mozjpeg '{"quality":85, "baseline":false, "arithmetic":false, "progressive":true, "optimize_coding":true, "smoothing":0,"color_space":3, "quant_table":3, "trellis_multipass":false, "trellis_opt_zero":false, "trellis_opt_table":false, "trellis_loops":1,"auto_subsample":true, "chroma_subsample":2, "separate_chroma_quality":false, "chroma_quality":75 }' "$jpeg_file"
                mogrify -set comment "optimised" "$jpeg_file"
                chown www-data:www-data "$jpeg_file"
                touch "$jpeg_file.optimised"
            fi
        fi
    fi
done

for png_file in *.png; do
        if [[ -f "$png_file" && ! -f "$png_file.optimised" ]]; then
        if [[ "$png_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
            echo "147 Skipping $png_file due to invalid characters in filename" >>"$log_file"
        else
        echo "Optimizing $png_file" >>"$log_file"
            if [[ $(identify -format %[comment] "$png_file") != *optimised* ]]; then
                echo "Optimizing $png_file" >>"$log_file"
                squoosh-cli --oxipng '{"level":6}' "$png_file"
                mogrify -set comment "optimised" "$png_file"
                chown www-data:www-data "$png_file"
                touch "$png_file.optimised"
            fi
        fi
    fi
done

for image_file in *.jpeg *.jpg *.png; do
    if [ -f "$image_file" ]; then
        if [[ "$image_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
            echo "164 Skipping $image_file due to invalid characters in filename" >>"$log_file"
        else

            if [ -f "${image_file}.webp" ] && [ "$(du -b -- "${image_file}.webp" | cut -f 1)" -gt "$(du -b -- "$image_file" | cut -f 1)" ]; then
                echo -e "webp is ${LYELLOW}bigger ${DBOLD}than $image_file, need delete webp"
                #tput sgr0
                rm -- "${image_file}.webp"
            fi
        fi
        if [[ "$image_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
            echo "174 Skipping $image_file due to invalid characters in filename" >>"$log_file"
        else
            if [ -f "${image_file}.avif" ] && [ "$(du -b -- "${image_file}.avif" | cut -f 1)" -gt "$(du -b -- "$image_file" | cut -f 1)" ]; then
                echo -e "avif is ${LYELLOW}bigger ${DBOLD}than $image_file, need delete avif"
                #tput sgr0
                rm -- "${image_file}.avif"
            fi
        fi
    fi
done

# Создание файлов-маркеров
for image_file in *.jpeg *.jpg *.png; do
    if [ -f "$image_file" ]; then
        if [[ "$image_file" =~ [^a-zA-Z0-9_.\-[:alnum:]_[:punct:]] ]]; then
            echo "189 Skipping $image_file due to invalid characters in filename" >>"$log_file"
        else
            touch -- "${image_file}.optimised"
        fi
    fi
done

# Логирование результатов
echo "Оптимизация изображений завершена в $(date)" >>"$log_file"

#tput sgr0
echo ""
exit 0
