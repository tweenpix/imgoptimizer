#!/bin/bash

# Базовая директория, где находятся сайты
base_dir="/var/www"  # Укажите путь к вашим сайтам, например: /var/www
images_dir="wp-content/uploads" # Путь до картинок

# Максимальное время выполнения скрипта (4 часа)
max_time="4h"

# Временный файл для контроля времени выполнения
temp_script="/tmp/imgoptimize_temp.sh"

# Создаём временный скрипт для обхода
cat <<EOF > $temp_script
#!/bin/bash
for site_dir in "$base_dir"/*; do
    if [[ -d "\$site_dir/$images_dir" ]]; then
        uploads_dir="\$site_dir/$images_dir"
        echo "Оптимизация изображений в \$uploads_dir"
        
        # Выполняем оптимизацию в директории uploads
        find "\$uploads_dir" -type d \( ! -name . \) -exec bash -c 'cd "\$1" && imgoptimize' _ {} \;
    else
        echo "Директория uploads не найдена в \$site_dir, пропуск"
    fi
done
EOF

# Делаем временный скрипт исполняемым
chmod +x $temp_script

# Ограничиваем выполнение 4 часами
timeout $max_time bash $temp_script

# Удаляем временный скрипт после завершения
rm -f $temp_script
