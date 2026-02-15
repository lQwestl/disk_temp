#!/bin/sh

echo ""
echo "========================================"
echo " ТЕМПЕРАТУРА ДИСКОВ"
echo "========================================"
echo ""

printf "%-8s | %-10s | %s\n" "Диск" "Температура" "Статус"
printf "%-8s-+-%-10s-+-%s\n" "--------" "----------" "------------"

# Функция для получения температуры SATA диска
get_sata_temp() {
    local disk=$1
    local temp=""
    
    # Пробуем разные атрибуты и методы
    temp=$(smartctl -A "/dev/$disk" 2>/dev/null | awk '/^194/ {print $10}')
    
    if [ -z "$temp" ] || [ "$temp" = "0" ] || [ "$temp" = "-" ]; then
        temp=$(smartctl -A "/dev/$disk" 2>/dev/null | awk '/^190/ {print $10}')
    fi
    
    if [ -z "$temp" ] || [ "$temp" = "0" ] || [ "$temp" = "-" ]; then
        temp=$(smartctl -a "/dev/$disk" 2>/dev/null | grep -i "Temperature_Celsius" | awk '{print $10}')
    fi
    
    if [ -z "$temp" ] || [ "$temp" = "0" ] || [ "$temp" = "-" ]; then
        temp=$(smartctl -a "/dev/$disk" 2>/dev/null | grep -i "Current Drive Temperature" | awk '{print $4}')
    fi
    
    echo "$temp"
}

# Функция проверки статуса с температурными порогами
check_status() {
    local disk=$1
    local temp=$2
    
    if [ -z "$temp" ] || [ "$temp" = "0" ] || [ "$temp" = "-" ]; then
        printf "%-8s | %10s | %s\n" "$disk" "---" "Нет данных"
        return
    fi
    
    # Убираем лишние символы, оставляем только цифры
    temp_clean=$(echo "$temp" | sed 's/[^0-9]//g')
    
    if [ -z "$temp_clean" ]; then
        printf "%-8s | %10s | %s\n" "$disk" "---" "Ошибка данных"
        return
    fi
    
    # Определяем статус с температурными порогами
    if echo "$disk" | grep -q "^nvme"; then
        # NVME диски: критическая температура 70°C
        if [ "$temp_clean" -lt 50 ]; then
            status="✓ Отлично"
        elif [ "$temp_clean" -lt 60 ]; then
            status="✓ Норма"
        elif [ "$temp_clean" -lt 70 ]; then
            status="⚠ Тепло"
        else
            status="✗ КРИТИЧЕСКАЯ"
        fi
    else
        # HDD диски: критическая температура 60°C
        if [ "$temp_clean" -lt 35 ]; then
            status="✓ Холодно"
        elif [ "$temp_clean" -lt 45 ]; then
            status="✓ Идеально"
        elif [ "$temp_clean" -lt 55 ]; then
            status="✓ Норма"
        elif [ "$temp_clean" -lt 60 ]; then
            status="⚠ Тепло"
        else
            status="✗ КРИТИЧЕСКАЯ"
        fi
    fi
    
    printf "%-8s | %9s°C | %s\n" "$disk" "$temp_clean" "$status"
}

echo "SATA/SCSI диски (HDD):"
echo "----------------------"

# Проверяем SATA/SCSI диски
for i in a b c d e f g h i; do
    disk="sd$i"
    if [ -e "/dev/$disk" ]; then
        temp=$(get_sata_temp "$disk")
        check_status "$disk" "$temp"
    fi
done

echo ""
echo "NVMe диски (SSD):"
echo "-----------------"

# Проверяем NVMe
if [ -e "/dev/nvme0" ]; then
    temp=$(nvme smart-log /dev/nvme0 2>/dev/null | grep -i "temperature" | head -1 | awk '{print $3}' | tr -d ',')
    temp=$(echo "$temp" | sed 's/°C//g')
    check_status "nvme0" "$temp"
fi

echo "========================================"
echo ""
echo "Справка по температурам:"
echo "• HDD: 35-55°C - норма, 55-60°C - тепло, 60+°C - критическая"
echo "• NVMe: 50-70°C - норма, 70+°C - критическая"
echo ""
