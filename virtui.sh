#!/bin/bash

# ==========================================
# Color & Style Definitions
# ==========================================
blue="\033[1;34m"
cyan="\033[1;36m"
green="\033[1;32m"
red="\033[1;31m"
yellow="\033[1;33m"
bold="\033[1m"
reset="\033[0m"

src_dir="/var/lib/libvirt/images"
dst_dir="/var/lib/libvirt/vms"
log_dir="${dst_dir}/log"
template_dir="${dst_dir}/templates"
log_file="${log_dir}/system_check.log"
vm_log_file="${log_dir}/create_vm.log"

# ==========================================
# UI Helper Functions
# ==========================================
log_info()    { echo -e "  [${blue}INFO${reset}] $1"; }
log_success() { echo -e "  [${green}OK${reset}] $1"; }
log_warn()    { echo -e "  [${yellow}WARN${reset}] $1"; }
log_fail()    { echo -e "  [${red}FAIL${reset}] $1"; }

draw_line() {
  echo -e "${blue}-------------------------------------------------------------------------------------${reset}"
}

pause() {
  echo ""
  echo -en "  Tekan ${bold}${yellow}[Enter]${reset} untuk melanjutkan! "
  read -r
  echo ""
}

show_banner() {
  clear
  echo -e "${blue}"
  echo "  ╔══════════════════════════════════════════════════════════════╗"
  echo "  ║   __  __  ______   ______  ______  __  __  ______            ║"
  echo "  ║  /\ \/\ \/\__  _\ /\  __ \/\__  _\/\ \/\ \/\__  _\           ║"
  echo "  ║  \ \ \ \ \/_/\ \/ \ \ \_\ \/_/\ \/\ \ \ \ \/_/\ \/           ║"
  echo "  ║   \ \ \ \ \ \ \ \  \ \ _  /  \ \ \ \ \ \ \ \ \ \ \           ║"
  echo "  ║    \ \ \_/ \ \_\ \__\ \ \ \ \ \ \ \ \ \ \_\ \ \ \ \__        ║"
  echo "  ║     \ \____/ /\______\ \_\ \_\ \ \_\ \ \_____\/\_____\       ║"
  echo "  ║      \_____/ \/_____/ \/_/\/_/  \/_/  \/_____/\/_____/       ║"
  echo -e "  ║              ${yellow}virtUI - Qemu/KVM TUI Management${blue}                ║"
  echo "  ║                                                              ║"
  echo "  ╚══════════════════════════════════════════════════════════════╝"
  echo -e "${reset}"
}

safe_replace() {
  local search="$1"
  local replace="$2"
  local filepath="$3"

  local escaped_replace
  escaped_replace="$(printf '%s\n' "${replace}" | sed -e 's/[\/&|\\]/\\&/g')"

  sed -i "s|${search}|${escaped_replace}|g" "${filepath}"
}

# write_log_raw() {
#   local clean_text
#   clean_text=$(echo -e "$1" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
#   mkdir -p "$(dirname "${log_file}")" 2>/dev/null
#   echo "${clean_text}" >> "${log_file}"
# }

write_log_raw() {
  local clean_text
  clean_text=$(echo -e "$1" | sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g')
  local target_dir
  target_dir="$(dirname "${log_file}")"

  # Tulis log hanya jika direktori ada dan user memiliki izin akses write
  if [[ -d "${target_dir}" && -w "${target_dir}" ]]; then
    echo "${clean_text}" >> "${log_file}"
  elif [[ -d "${target_dir}" ]]; then
    echo "${clean_text}" | sudo tee -a "${log_file}" >/dev/null
  fi
}

# ==========================================
# SYSTEM CHECK FUNCTIONS (MENU 1)
# ==========================================
valid_workdir() {
  draw_line
  echo -e "${bold}1. Memeriksa Direktori Kerja (Storage Pool & Destination)${reset}"

  local target_owner="$USER"
  local target_group="libvirt"
  local target_perm="2775"
  local log_buffer=()

  # Tampung log awal ke buffer sebelum file log diinisialisasi
  log_buffer+=("--------------------------------------------------")
  log_buffer+=("1. Memeriksa Direktori Kerja (Storage Pool & Destination)")

  for dir in "${src_dir}" "${dst_dir}" "${log_dir}" "${template_dir}"; do
    # 1. Pengecekan Keberadaan Direktori
    if [[ ! -d "${dir}" ]]; then
      log_warn "Membuat direktori ${cyan}${dir}${reset}..."
      sudo mkdir -p "${dir}"
      cp -R templates "${template_dir}"
      log_success "Direktori ${cyan}${dir}${reset} berhasil dibuat."
      log_buffer+=("  [OK] Membuat direktori ${dir}.")
    else
      log_success "Direktori ${cyan}${dir}${reset} sudah ada."
      log_buffer+=("  [OK] Direktori ${dir} sudah ada.")
    fi

    # 2. Pengecekan Ownership (User:Group)
    local current_owner_group
    current_owner_group="$(stat -c "%U:%G" "${dir}" 2>/dev/null)"

    if [[ "${current_owner_group}" != "${target_owner}:${target_group}" ]]; then
      log_warn "Ownership ${cyan}${dir}${reset} (${current_owner_group}) belum sesuai. Mengubah ke ${target_owner}:${target_group}..."
      sudo chown -R "${target_owner}:${target_group}" "${dir}"
      log_success "Ownership ${cyan}${dir}${reset} diperbarui ke ${target_owner}:${target_group}."
      log_buffer+=("  [OK] Ownership ${dir} diperbarui (${current_owner_group} -> ${target_owner}:${target_group}).")
    else
      log_success "Ownership ${cyan}${dir}${reset} sudah sesuai (${target_owner}:${target_group})."
      log_buffer+=("  [OK] Ownership ${dir} sesuai (${target_owner}:${target_group}).")
    fi

    # 3. Pengecekan Permission (Mode Oktal)
    local current_perm
    current_perm="$(stat -c "%a" "${dir}" 2>/dev/null)"

    if [[ "${current_perm}" != "${target_perm}" ]]; then
      log_warn "Permission ${cyan}${dir}${reset} (${current_perm}) belum sesuai. Mengubah ke ${target_perm}..."
      sudo chmod "${target_perm}" "${dir}"
      log_success "Permission ${cyan}${dir}${reset} diperbarui ke ${target_perm}."
      log_buffer+=("  [OK] Permission ${dir} diperbarui (${current_perm} -> ${target_perm}).")
    else
      log_success "Permission ${cyan}${dir}${reset} sudah sesuai (${target_perm})."
      log_buffer+=("  [OK] Permission ${dir} sesuai (${target_perm}).")
    fi
  done

  # --- INISIALISASI FILE LOG ---
  # Pada titik ini log_dir dipastikan SUDAH ADA dan PERMISSION SUDAH BENAR untuk $USER
  local current_time
  current_time="$(date '+%Y-%m-%d %H:%M:%S')"
  cat <<EOF > "${log_file}"
[${current_time}] virtUI Pengecekan Sistem & Dependensi Terakhir

EOF

  # Flushing log buffer ke file log secara aman
  for line in "${log_buffer[@]}"; do
    write_log_raw "${line}"
  done
}

valid_support() {
  draw_line
  echo -e "${bold}2. Memeriksa Dukungan Virtualisasi Hardware${reset}"
  write_log_raw "--------------------------------------------------"
  write_log_raw "2. Memeriksa Dukungan Virtualisasi Hardware"

  if ! lscpu | grep "^Virtualization" > /dev/null 2>&1; then
    log_fail "Sistem tidak mendukung virtualisasi hardware. Cek konfigurasi BIOS/VT-x."
    write_log_raw "  [FAIL] Sistem tidak mendukung virtualisasi hardware."
    return 1
  else
    local virt_info
    virt_info="$(lscpu | grep "^Virtualization")"
    log_success "Sistem mendukung virtualisasi:"
    echo -e "      ${yellow}${virt_info}${reset}"
    write_log_raw "  [OK] Sistem mendukung virtualisasi:"
    write_log_raw "      ${virt_info}"
  fi
}

valid_package() {
  draw_line
  echo -e "${bold}3. Memeriksa Depedensi Package Libvirt${reset}"
  write_log_raw "--------------------------------------------------"
  write_log_raw "3. Memeriksa Depedensi Package Libvirt"

  declare -a packages=("cpu-checker" "ipcalc" "whois" "qemu-system" "libvirt-daemon-system" "virtinst" "libosinfo-bin" "genisoimage" "python3")
  local missing_packages=()
  for pack in "${packages[@]}"; do
    if ! dpkg-query -W -f='${Status}' "${pack}" 2>/dev/null | grep -q "ok installed"; then
      log_warn "Package ${red}${pack}${reset} belum terinstall"
      missing_packages+=("${pack}")
    else
      log_success "Package ${cyan}${pack}${reset} sudah terinstall"
      write_log_raw "  [OK] Package ${pack} sudah terinstall"
    fi
  done

  if [[ ${#missing_packages[@]} -gt 0 ]]; then
    log_info "Tunggu! Sedang menginstall package: ${yellow}${missing_packages[*]}${reset}"
    if sudo apt update -y >/dev/null 2>&1 && sudo apt install -y "${missing_packages[@]}" >/dev/null 2>&1; then
      for pack in "${missing_packages[@]}"; do
        log_success "Package ${cyan}${pack}${reset} berhasil diinstall"
        write_log_raw "  [OK] Package ${pack} berhasil diinstall"
      done
    else
      log_fail "Gagal menginstall beberapa package!"
      write_log_raw "  [FAIL] Gagal menginstall package: ${missing_packages[*]}"
      return 1
    fi
  fi
}

valid_nested() {
  draw_line
  echo -e "${bold}4. Memeriksa Nested Virtualization${reset}"
  write_log_raw "--------------------------------------------------"
  write_log_raw "4. Memeriksa Nested Virtualization"

  nested_module="$(lsmod | grep -E "^kvm_amd|^kvm_intel" | awk '{print $1}')"
  if [[ -n "${nested_module}" ]]; then
    nested_value="$(cat /sys/module/${nested_module}/parameters/nested 2>/dev/null)"
    if [[ "${nested_value}" != "1" && "${nested_value}" != "Y" ]]; then
      log_warn "Nested virtualization nonaktif."
      read -p "  Aktifkan nested virtualization? (Y/n, default Y): " nested_response
      nested_response=${nested_response:-Y}
      if [[ "${nested_response}" =~ ^[Yy]$ ]]; then
        echo "options ${nested_module} nested=1" | sudo tee /etc/modprobe.d/kvm.conf > /dev/null
        sudo modprobe -r "${nested_module}" 2>/dev/null || true
        sudo modprobe "${nested_module}"
        log_success "Nested virtualization berhasil diaktifkan"
        write_log_raw "  [OK] Nested virtualization diaktifkan (modul: ${nested_module})"
      else
        log_warn "Nested virtualization dilewati."
        write_log_raw "  [WARN] Nested virtualization dilewati oleh user."
      fi
    else
      log_success "Nested virtualization aktif (${cyan}modul: ${nested_module}${reset})"
      write_log_raw "  [OK] Nested virtualization aktif (modul: ${nested_module})"
    fi
  else
    log_warn "Modul KVM tidak terdeteksi."
    write_log_raw "  [WARN] Modul KVM tidak terdeteksi."
  fi
}

valid_user() {
  draw_line
  echo -e "${bold}5. Memeriksa Group Membership Libvirt${reset}"
  write_log_raw "--------------------------------------------------"
  write_log_raw "5. Memeriksa Group Membership Libvirt"

  if ! id -nG "$USER" | grep -qw "libvirt"; then
    log_warn "User ${red}${USER}${reset} belum masuk ke group 'libvirt'."
    sudo usermod -aG libvirt "$USER"
    log_success "User ${cyan}${USER}${reset} telah ditambahkan ke group 'libvirt' (Perlu relogin)."
    write_log_raw "  [OK] User ${USER} ditambahkan ke group 'libvirt'"
  else
    log_success "User ${cyan}${USER}${reset} sudah menjadi anggota group 'libvirt'"
    write_log_raw "  [OK] User ${USER} sudah menjadi anggota group 'libvirt'"
  fi
}

valid_one_image() {
  draw_line
  echo -e "${bold}6. Memeriksa Ketersediaan Base OS Image${reset}"
  write_log_raw "--------------------------------------------------"
  write_log_raw "6. Memeriksa Ketersediaan Base OS Image"

  shopt -s nullglob
  local images=("${src_dir}"/*)
  shopt -u nullglob

  if [[ ${#images[@]} -eq 0 ]]; then
    log_warn "Direktori ${cyan}${src_dir}${reset} kosong."
    log_info "Mendownload base image ${cyan}Ubuntu 20.04 Cloud Image${reset}..."
    sudo wget -nv https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -O "${src_dir}/focal-server-cloudimg-amd64.img"
    if [[ -f "${src_dir}/focal-server-cloudimg-amd64.img" ]]; then
      log_success "Berhasil mendownload base image."
      write_log_raw "  [OK] Base image berhasil didownload ke ${src_dir}."
    else
      log_fail "Gagal mendownload base image."
      write_log_raw "  [FAIL] Gagal mendownload base image."
    fi
  else
    log_success "Base image ditemukan di ${cyan}${src_dir}${reset}."
    write_log_raw "  [OK] Base image ditemukan di ${src_dir}."
  fi
}

run_system_checks() {
  show_banner
  echo -e "${bold}${yellow}>>> MENJALANKAN PENGECEKAN SISTEM & DEPENDENSI <<<${reset}\n"

#   local current_time
#   current_time="$(date '+%Y-%m-%d %H:%M:%S')"

#   # Reset/Overwrite log file dengan header timestamp
#   mkdir -p "${log_dir}" 2>/dev/null
#   cat <<EOF > "${log_file}"
# [${current_time}] virtUI Pengecekan Sistem & Dependensi Terakhir

# EOF

  local stat_supp=1 stat_pkg=1 stat_nest=1 stat_usr=1 stat_work=1 stat_img=1
  valid_workdir   && stat_work=0
  valid_support   && stat_supp=0
  valid_package   && stat_pkg=0
  valid_nested    && stat_nest=0
  valid_user      && stat_usr=0
  valid_one_image && stat_img=0

  icon() {
    if [[ $1 -eq 0 ]]; then echo "✔"; else echo "✖"; fi
  }

  icon_color() {
    if [[ $1 -eq 0 ]]; then echo -e "${green}✔${reset}"; else echo -e "${red}✖${reset}"; fi
  }

  # Tulis Ringkasan ke Log File
  {
    echo "--------------------------------------------------"
    echo "  RINGKASAN PENGECEKAN SISTEM:"
    echo "  [$(icon $stat_work)] Kesiapan Storage Pool & Folder Log"
    echo "  [$(icon $stat_supp)] Dukungan Hardware Virtualization"
    echo "  [$(icon $stat_pkg)] Depedensi Package Libvirt"
    echo "  [$(icon $stat_nest)] Konfigurasi Nested Virtualization"
    echo "  [$(icon $stat_usr)] User Group Membership (libvirt)"
    echo "  [$(icon $stat_img)] Ketersediaan Base OS Image"
    echo "--------------------------------------------------"
    echo ""
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Complete: virtUI Pengecekan Sistem & Dependensi"
  } >> "${log_file}"

  # Tampilan Ringkasan di Terminal
  draw_line
  echo -e "  ${bold}RINGKASAN PENGECEKAN SISTEM:${reset}\n"
  echo -e "  [$(icon_color $stat_work)] Kesiapan Storage Pool & Folder Log"
  echo -e "  [$(icon_color $stat_supp)] Dukungan Hardware Virtualization"
  echo -e "  [$(icon_color $stat_pkg)] Depedensi Package Libvirt"
  echo -e "  [$(icon_color $stat_nest)] Konfigurasi Nested Virtualization"
  echo -e "  [$(icon_color $stat_usr)] User Group Membership (libvirt)"
  echo -e "  [$(icon_color $stat_img)] Ketersediaan Base OS Image"
  draw_line

  log_info "Log aktivitas tersimpan di: ${yellow}${log_file}${reset}"
  pause
}

view_last_log() {
  show_banner
  echo -e "${bold}${yellow}>>> LOG PENGECEKAN SISTEM TERAKHIR <<<${reset}\n"

  if [[ -f "${log_file}" ]]; then
    draw_line
    cat "${log_file}"
    draw_line
  else
    log_warn "File log belum ditemukan di: ${cyan}${log_file}${reset}"
    log_info "Jalankan 'Pengecekan Sistem & Dependensi' terlebih dahulu."
  fi
  pause
}

view_vm_log() {
  show_banner
  echo -e "${bold}${yellow}>>> LOG RIWAYAT PEMBUATAN VM <<<${reset}\n"

  if [[ -f "${vm_log_file}" ]]; then
    draw_line
    cat "${vm_log_file}"
    draw_line
  else
    log_warn "File log pembuatan VM belum ditemukan di: ${cyan}${vm_log_file}${reset}"
    log_info "Jalankan 'Buat Virtual Machine Baru' terlebih dahulu."
  fi
  pause
}

view_log_menu() {
  while true; do
    show_banner
    echo -e "  ${bold}SUB-MENU MANAJEMEN LOG SYSTEM & VM:${reset}\n"
    echo -e "   [${cyan}1${reset}] Lihat Log Pengecekan Sistem (System Health Check)"
    echo -e "   [${cyan}2${reset}] Lihat Log Riwayat Pembuatan VM (VM Creation)"
    echo -e "   [${cyan}0${reset}] Kembali ke Menu Utama"
    echo ""
    draw_line
    read -e -p "  Masukkan pilihan [0-2]: " log_opt
    case $log_opt in
      1)
        view_last_log
        ;;
      2)
        view_vm_log
        ;;
      0)
        break
        ;;
      *)
        log_fail "Pilihan tidak valid!"
        sleep 1
        ;;
    esac
  done
}

# ==========================================
# VM CREATION FUNCTIONS (MENU 2)
# ==========================================
valid_name() {
  draw_line
  local default_name="vm$(date +%d_%m_%y)"

  while true; do
    read -e -i "${default_name}" -p "  Masukkan Nama VM: " vm_name
    if virsh list --all --name | grep -qwF -- "${vm_name}"; then
      log_fail "Nama VM '${vm_name}' sudah digunakan! Silakan gunakan nama lain"
    else
      log_info "Nama VM diset ke: ${yellow}${vm_name}${reset}"
      break
    fi
  done
}

valid_mem() {
  draw_line
  local vm_mem_max
  vm_mem_max="$(grep -i "MemAvailable" /proc/meminfo | awk '{print int($2/1024)}')"
  log_info "Total RAM tersedia: ${yellow}${vm_mem_max} MiB${reset}"

  while true; do
    read -e -p "  Alokasi RAM untuk VM (dalam MiB, contoh: 1024, 2048): " vm_mem
    if [[ "${vm_mem}" =~ ^[0-9]+$ ]] && [[ "${vm_mem}" -gt 0 ]] && [[ "${vm_mem}" -lt "${vm_mem_max}" ]]; then
      log_info "RAM dialokasikan: ${yellow}${vm_mem} MiB${reset}"
      break
    else
      log_fail "Ukuran RAM tidak valid! Masukkan angka di bawah ${vm_mem_max} MiB."
    fi
  done
}

valid_cpu() {
  draw_line
  local max_cpu="$(nproc)"
  log_info "Total CPU Core tersedia: ${yellow}${max_cpu} core${reset}"

  while true; do
    read -e -i "1" -p "  Alokasi CPU Core untuk VM: " vm_cpu
    if [[ "${vm_cpu}" =~ ^[0-9]+$ ]] && [[ "${vm_cpu}" -ge 1 ]] && [[ "${vm_cpu}" -le "${max_cpu}" ]]; then
      log_info "CPU Core dialokasikan: ${yellow}${vm_cpu} Core${reset}"
      break
    else
      log_fail "Jumlah Core tidak valid! Masukkan angka antara 1 - ${max_cpu}."
    fi
  done
}

valid_os_image() {
  shopt -s nullglob
  os_images=("${src_dir}"/*)
  shopt -u nullglob

  if [[ ${#os_images[@]} -eq 0 ]]; then
    log_fail "Tidak ada image di ${src_dir}! Jalankan Menu Pengecekan Sistem terlebih dahulu."
    return 1
  fi

  local os_filenames=()
  for img in "${os_images[@]}"; do
    os_filenames+=("$(basename "${img}")")
  done

  echo -e "  ${bold}Daftar OS Image Tersedia:${reset}"
  for idx in "${!os_filenames[@]}"; do
    echo -e "   [${cyan}$((idx + 1))${reset}] ${os_filenames[idx]}"
  done

  while true; do
    read -e -p "  Pilih OS Image (masukkan nomor): " vm_os
    if [[ "${vm_os}" =~ ^[0-9]+$ ]] && [[ "${vm_os}" -ge 1 ]] && [[ "${vm_os}" -le "${#os_filenames[@]}" ]]; then
      selected_os_image="${os_filenames[$((vm_os - 1))]}"
      break
    else
      log_fail "Pilihan tidak valid!"
    fi
  done
}

valid_disk_available() {
  draw_line
  echo -e "  ${bold}Informasi Kapasitas Storage Pool Libvirt:${reset}\n"
  local pool_list
  pool_list=$(virsh pool-list --all --name 2>/dev/null)

  if [[ -z "${pool_list}" ]]; then
    log_warn "Tidak ada Storage Pool Libvirt yang terdaftar."
    return 1
  fi

  for pool_storage in ${pool_list}; do
    local pool_info
    pool_info=$(virsh pool-info --pool "${pool_storage}" 2>/dev/null)

    local state cap avail path
    state=$(echo "${pool_info}" | awk '/State:/ {print $2}')

    if [[ "${state}" == "running" ]]; then
      cap=$(echo "${pool_info}" | awk '/Capacity:/ {print $2 " " $3}')
      avail=$(echo "${pool_info}" | awk '/Available:/ {print $2 " " $3}')
      path=$(virsh pool-dumpxml --pool "${pool_storage}" 2>/dev/null | awk -F"[<>]" '/<path>/{print $3}')

      echo -e "  - Pool: ${cyan}${pool_storage}${reset} (${green}Active${reset})"
      [[ -n "${path}" ]] && echo -e "    Path : ${yellow}${path}${reset}"
      echo -e "    Space: Tersedia ${avail} (Total ${cap})\n"
    else
      echo -e "  - Pool: ${cyan}${pool_storage}${reset} (${red}Inactive${reset})\n"
    fi
  done
}

valid_clone_image() {
  src_img=$1
  dst_img=$2
  dst_path="${dst_dir}/${dst_img}"
  qemu-img create -q -b "${src_dir}/${src_img}" -f qcow2 -F qcow2 "${dst_path}" "${vm_disk1_size}G"
  echo "${dst_path}"
}

valid_primary_disk() {
  draw_line
  valid_os_image || return 1
  valid_disk_available

  while true; do
    read -e -i "15" -p "  Alokasi Ukuran Primary Disk (dalam GiB): " vm_disk1_size
    if [[ "${vm_disk1_size}" =~ ^[0-9]+$ && "${vm_disk1_size}" -gt 0 ]]; then
      break
    else
      log_fail "Ukuran disk tidak valid! Masukkan angka bulat positif lebih dari 0."
    fi
  done

  local current_ts
  current_ts=$(date +%d_%m_%y_%H_%M_%S)

  log_info "Memproses cloning image dari base template..."
  # local os_idx=$(( vm_os - 1 ))
  # vm_disk1=$(valid_clone_image "${os_images[${os_idx}]}" "${os_images[${os_idx}]}-${current_ts}.img")
  vm_disk1=$(valid_clone_image "${selected_os_image}" "${selected_os_image}-${current_ts}.img")
  log_success "Primary disk berhasil dibuat di: ${yellow}${vm_disk1}${reset}"

  log_info "Mendeteksi OS Variant dari nama file image..."
  local vm_disk1_basename
  vm_disk1_basename=$(basename "${vm_disk1}")

  local ospattern=()
  ospattern+=($(echo "${vm_disk1_basename}" | awk -F'-' '{print $1}'))
  ospattern+=($(echo "${vm_disk1_basename}" | awk -F'-' '{print $2}'))
  ospattern+=($(echo "${vm_disk1_basename}" | awk -F'-' '{print $4}'))
  ospattern+=($(echo "${vm_disk1_basename}" | grep -oP '[0-9]+\.[0-9]+'))

  local osinfo=()
  mapfile -t osinfo < <(osinfo-query os --fields=short-id,name,codename 2>/dev/null | grep -i "${ospattern[0]}" | awk '{print $1}')

  local osfilter=() osfilter1=() osfilter2=()
  local osfinal_arr=()
  local i=0

  if [[ "${#osinfo[@]}" -eq 1 ]]; then
    osfinal_arr+=("${osinfo[@]}")
  elif [[ "${#osinfo[@]}" -gt 1 ]]; then
    i=0
    while [[ "${i}" -lt "${#ospattern[@]}" ]]; do
      mapfile -t osfilter < <(printf '%s\n' "${osinfo[@]}" | grep -i "${ospattern[$i]}")
      if [[ "${#osfilter[@]}" -eq 1 ]]; then
        osfinal_arr+=("${osfilter[@]}")
        break
      fi
      ((i++))
    done

    if [[ "${#osfilter[@]}" -gt 1 ]]; then
      i=1
      while [[ "${i}" -lt "${#ospattern[@]}" ]]; do
        mapfile -t osfilter1 < <(printf '%s\n' "${osfilter[@]}" | grep -i "${ospattern[$i]}")
        if [[ "${#osfilter1[@]}" -eq 1 ]]; then
          osfinal_arr+=("${osfilter1[@]}")
          break
        else
          osfilter2+=("${osfilter1[@]}")
          break
        fi
        ((i++))
      done
    fi

    if [[ "${#osfilter2[@]}" -gt 1 ]]; then
      i=0
      while [[ "${i}" -lt "${#ospattern[@]}" ]]; do
        mapfile -t osfinal_arr < <(printf '%s\n' "${osfilter2[@]}" | grep -i "${ospattern[$i]}")
        if [[ "${#osfinal_arr[@]}" -eq 1 ]]; then
          break
        fi
        ((i++))
      done
    fi
  fi

  if [[ "${#osfinal_arr[@]}" -gt 0 && -n "${osfinal_arr[0]}" ]]; then
    osfinal="${osfinal_arr[0]}"
    log_success "OS Variant terdeteksi: ${yellow}${osfinal}${reset}"
  else
    osfinal="linux2020"
    log_warn "OS Variant tidak terdeteksi secara presisi. Menggunakan fallback: ${yellow}${osfinal}${reset}"
  fi
}

# valid_extended_disk_size() {
  # if [[ "${extended_disk_size}" =~ ^[0-9]+$ && "${extended_disk_size}" -gt 0 ]]; then
    # local pdisk_path="${dst_dir}/${vm_name}-disk${i}.qcow2"
    # log_info "Membuat disk extended #${i} di ${pdisk_path}..."
    # qemu-img create -f qcow2 "${pdisk_path}" "${extended_disk_size}G" > /dev/null
    # disk_extended+=(--disk "path=${pdisk_path},format=qcow2")
    # log_success "Disk tambahan #${i} (${extended_disk_size} GiB) berhasil dibuat."
  # else
    # log_fail "Ukuran disk tidak valid! Harap masukkan angka bulat positif ( > 0 )."
    # read -e -p "  Masukkan kembali ukuran disk tambahan (dalam GiB): " extended_disk_size
    # valid_extended_disk_size
  # fi
# }

# valid_extended_disk_count() {
  # draw_line
  # read -e -i "0" -p "  Jumlah disk tambahan yang ingin dibuat (0 jika tidak ada): " extended_disk_count
# 
  # if [[ ! "${extended_disk_count}" =~ ^[0-9]+$ ]]; then
    # log_fail "Input tidak valid! Harap masukkan angka bulat positif atau 0."
    # valid_extended_disk_count
    # return
  # fi
# 
  # if [[ "${extended_disk_count}" -eq 0 ]]; then
    # log_info "Tidak ada disk tambahan yang akan dibuat."
    # disk_extended=()
    # return
  # fi
  # disk_extended=()
# 
  # local i
  # for (( i=1; i<=extended_disk_count; i++ )); do
    # echo -e "\n  ${cyan}[Disk Tambahan #${i}]${reset}"
    # read -e -i "10" -p "  Masukkan ukuran Disk #${i} (dalam GiB): " extended_disk_size
    # valid_extended_disk_size
  # done
# }

# valid_extended_disk() {
  # draw_line
  # read -e -p "  Apakah ingin menambah disk tambahan (extended)? (y/N): " extended_disk_response
  # if [[ "${extended_disk_response}" =~ ^[Yy]$ ]]; then
    # valid_extended_disk_count
  # else
    # log_info "Tanpa disk tambahan."
  # fi
# }

valid_extended_disk() {
  draw_line
  read -e -p "  Apakah ingin menambah disk tambahan (extended)? (y/N): " extended_disk_response
  if [[ ! "${extended_disk_response}" =~ ^[Yy]$ ]]; then
    log_info "Tanpa disk tambahan."
    disk_extended=()
    return 0
  fi

  local extended_disk_count
  while true; do
    read -e -i "0" -p "  Jumlah disk tambahan yang ingin dibuat (0 jika tidak ada): " extended_disk_count
    if [[ "${extended_disk_count}" =~ ^[0-9]+$ ]]; then
      if [[ "${extended_disk_count}" -eq 0 ]]; then
        log_info "Tidak ada disk tambahan yang akan dibuat."
        disk_extended=()
        return 0
      fi
      break
    else
      log_fail "Input tidak valid! Harap masukkan angka bulat positif atau 0."
    fi
  done

  # if [[ "${extended_disk_count}" -eq 0 ]]; then
    # log_info "Tidak ada disk tambahan yang akan dibuat."
    # disk_extended=()
    # return 0
  # fi

  disk_extended=()
  local i
  for (( i=1; i<=extended_disk_count; i++ )); do
    echo -e "\n  ${cyan}[Disk Tambahan #${i}]${reset}"
    local extended_disk_size
    while true; do
      read -e -i "10" -p "  Masukkan ukuran Disk #${i} (dalam GiB): " extended_disk_size
      if [[ "${extended_disk_size}" =~ ^[0-9]+$ && "${extended_disk_size}" -gt 0 ]]; then
        local pdisk_path="${dst_dir}/${vm_name}-disk${i}.qcow2"
        log_info "Membuat disk extended #${i} di ${pdisk_path}..."
        qemu-img create -f qcow2 "${pdisk_path}" "${extended_disk_size}G" > /dev/null
        disk_extended+=(--disk "path=${pdisk_path},format=qcow2")
        log_success "Disk tambahan #${i} (${extended_disk_size} GiB) berhasil dibuat."
        break
      else
        log_fail "Ukuran disk tidak valid! Harap masukkan angka bulat positif ( > 0 )."
      fi
    done
  done
}

valid_vir_net() {
  local net_name=()
  local net_if=()
  local net iface

  for net in $(virsh net-list --all --name 2>/dev/null); do
    if [[ -n "${net}" ]]; then
      iface="$(virsh net-dumpxml "${net}" 2>/dev/null | awk -F"'" '/bridge name=/{print $2}')"
      [[ -z "${iface}" ]] && iface="N/A"
      net_name+=("${net}")
      net_if+=("${iface}")
    fi
  done

  if [[ "${#net_name[@]}" -eq 0 ]]; then
    log_fail "Tidak ada Virtual Network Libvirt yang ditemukan di sistem!"
    log_info "Buat Virtual Network di Libvirt terlebih dahulu."
    return 1
  fi

  echo -e "  ${bold}Daftar Virtual Network yang tersedia:${reset}"
  local vnet num
  for vnet in "${!net_name[@]}"; do
    num=$((vnet + 1))
    echo -e "   [${cyan}${num}${reset}] Net: ${yellow}${net_name[${vnet}]}${reset} | Iface: ${cyan}${net_if[${vnet}]}${reset}"
  done
  echo ""

  local net_num
  while true; do
    read -e -p "  Pilih nomor Virtual Network [1-${#net_name[@]}]: " net_num

    if [[ "${net_num}" =~ ^[0-9]+$ && "${net_num}" -gt 0 && "${net_num}" -le "${#net_name[@]}" ]]; then
      local idx=$((net_num - 1))
      vm_net_select="${net_name[${idx}]}"
      vm_if_select="${net_if[${idx}]}"
      ip_gw="$(ip -4 addr show "${vm_if_select}" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"

      if [[ -z "${ip_gw}" ]]; then
        log_warn "Interface '${vm_if_select}' tidak memiliki IP aktif. Gateway: ${yellow}${ip_gw}${reset}"
      else
        log_success "Virtual Network terpilih: ${yellow}${vm_net_select}${reset} (${vm_if_select})"
        log_info "Terdeteksi Gateway Host: ${yellow}${ip_gw}${reset}"
      fi
      break
    else
      log_fail "Pilihan tidak valid! Harap masukkan nomor antara 1 hingga ${#net_name[@]}."
    fi
  done
}

valid_ip() {
  draw_line
  local ip_gw_clean="${ip_gw%%/*}"
  local ip_prefix="${ip_gw_clean%.*}"
  local default_ip="${ip_prefix}.10"
  log_info "Gateway Host: ${yellow}${ip_gw_clean}${reset}"
  local ip_net
  ip_net="$(ipcalc -n "${ip_gw_clean}" 2>/dev/null | awk -F: '/Network/ {gsub(/ /, "", $2); print $2}' | cut -d/ -f1)"
  netmask="$(ipcalc "${ip_gw_clean}" 2>/dev/null | awk -F: '/Netmask/ {gsub(/ /, "", $2); print $2}' | cut -d= -f1)"
  [[ -z "${netmask}" ]] && netmask="255.255.255.0"

  local ip_num_input
  while true; do
    read -e -i "${default_ip}" -p "  Masukkan Static IP untuk VM: " ip_num_input

    if [[ ! "${ip_num_input}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      log_fail "Format IP Address tidak valid! Contoh format yang benar: 192.168.122.10"
      continue
    fi

    local valid_octets=true
    local octets
    IFS='.' read -r -a octets <<< "${ip_num_input}"
    for octet in "${octets[@]}"; do
      if [[ "${octet}" -gt 255 ]]; then
        valid_octets=false
        break
      fi
    done

    if [[ "${valid_octets}" == false ]]; then
      log_fail "Angka IP tidak boleh melebihi 255 pada tiap oktetnya!"
      continue
    fi

    if [[ "${ip_num_input}" == "${ip_gw_clean}" ]]; then
      log_fail "IP Address tidak boleh sama dengan IP Gateway (${ip_gw_clean})!"
      continue
    fi

    local ip_input_net
    ip_input_net="$(ipcalc -n "${ip_num_input}" "${netmask}" 2>/dev/null | awk -F: '/Network/ {gsub(/ /, "", $2); print $2}' | cut -d/ -f1)"

    if [[ -n "${ip_net}" && -n "${ip_input_net}" && "${ip_input_net}" != "${ip_net}" ]]; then
      log_fail "IP Address '${ip_num_input}' berada di luar subnet jaringan Gateway (${ip_net})!"
      continue
    fi

    ip_num="${ip_num_input}"
    log_success "IP Address VM diset ke: ${yellow}${ip_num}${reset}"
    break
  done
}

valid_access_login() {
  draw_line
  read -e -i "john" -p "  Username akses VM: " vm_user

  read -e -s -p "  Password username: " vm_pass

  if [[ ! -f ~/.ssh/id_ed25519.pub ]]; then
    log_info "Generating SSH Key ed25519..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""
  fi

  local default_pubkey
  default_pubkey="$(cat ~/.ssh/id_ed25519.pub 2>/dev/null)"
  read -e -i "${default_pubkey}" -p "  SSH Public Key (Autofill): " vm_pubkey
  ssh_key_content="$(echo "${vm_pubkey}" | tr -d '\r\n' | xargs)"
  echo ""
}

valid_cloud_init() {
  draw_line
  valid_vir_net || return 1
  valid_ip
  valid_access_login

  local os_template="${osfinal}"
  local iso_path="${dst_dir}/${vm_name}-cloud-init.iso"

  if [[ -z "${os_template}" ]]; then
    log_info "OS template kosong, mengabaikan Cloud-Init..."
    rm -f "${iso_path}"
    return 0
  fi

  local os_type="${os_template}"
  local user_tpl=""
  local net_tpl=""

  case "${os_type}" in
    *ubuntu*|*debian*)
      user_tpl="user-data-1.tpl"
      net_tpl="network-config-1.tpl"
      ;;
    *rhel*|*centos*|*rocky*|*alma*|*fedora*)
      user_tpl="user-data-1.tpl"
      net_tpl="network-config-2.tpl"
      ;;
    *alpine*)
      user_tpl="user-data-2.tpl"
      net_tpl="network-config-2.tpl"
      ;;
    *linux2020*|*openwrt*|*custom*)
      log_info "Tidak tersedia template Cloud init untuk OS (${yellow}${os_template}${reset})"
      log_info "Melewati proses pembuatan Cloud-Init ISO..."
      rm -f "${iso_path}"
      return 0
      ;;
    *)
      log_warn "OS (${os_template}) tidak dikenal, menggunakan fallback template default."
      user_tpl="user-data-1.tpl"
      net_tpl="network-config-1.tpl"
      ;;
  esac

  local user_template="${template_dir}/${user_tpl}"
  local meta_template="${template_dir}/meta-data"
  local network_template="${template_dir}/${net_tpl}"

  if [[ ! -f "${user_template}" || ! -f "${meta_template}" || ! -f "${network_template}" ]]; then
    log_fail "Template (${user_tpl} / meta-data / ${net_tpl}) tidak ditemukan di ${template_dir}!"
    return 1
  fi

  log_info "Menggunakan template: ${yellow}${user_tpl}${reset} & ${yellow}${net_tpl}${reset}"

  local cloud_dir="/tmp/cloud-init-${vm_name}"
  mkdir -p "${cloud_dir}"
  log_info "Memproses template dan mereplace variabel..."
  
  local hashed_pass=""
  if [[ -n "${vm_pass}" ]]; then
    if [[ "${os_type}" == *alpine* ]]; then
      hashed_pass="${vm_pass}"
    else
      hashed_pass="$(openssl passwd -6 "${vm_pass}" 2>/dev/null)"
    fi
  fi

  cp "${user_template}" "${cloud_dir}/user-data"
  cp "${meta_template}" "${cloud_dir}/meta-data"
  cp "${network_template}" "${cloud_dir}/network-config"

  local ip_gw_clean="${ip_gw%%/*}"

  # Replace variabel user-data
  safe_replace "__VM_NAME__" "${vm_name}" "${cloud_dir}/user-data"
  safe_replace "__VM_USER__" "${vm_user}" "${cloud_dir}/user-data"
  safe_replace "__VM_HASHED_PASS__" "${hashed_pass}" "${cloud_dir}/user-data"
  safe_replace "__SSH_KEY__" "${ssh_key_content}" "${cloud_dir}/user-data"
  safe_replace "__IP_NUM__" "${ip_num}" "${cloud_dir}/user-data"
  safe_replace "__IP_GW__" "${ip_gw_clean}" "${cloud_dir}/user-data"

  # Replace variabel meta-data
  safe_replace "__VM_NAME__" "${vm_name}" "${cloud_dir}/meta-data"

  # Replace variabel network-config
  safe_replace "__IP_NUM__" "${ip_num}" "${cloud_dir}/network-config"
  safe_replace "__IP_GW__" "${ip_gw_clean}" "${cloud_dir}/network-config"

  # 4. Generate ISO
  log_info "Membuat file ISO Cloud-Init..."
  log_info "Menginjeksi user-data, meta-data, dan network-config ke dalam ISO"

  if genisoimage -output "${iso_path}" -volid cidata -joliet -rock \
    "${cloud_dir}/user-data" \
    "${cloud_dir}/meta-data" \
    "${cloud_dir}/network-config" &>/dev/null; then
    
    log_success "Cloud-Init ISO berhasil dibuat: ${yellow}${iso_path}${reset}"
    # rm -rf "${cloud_dir}"
    return 0
  else
    log_fail "Gagal membuat ISO Cloud-Init menggunakan genisoimage!"
    rm -rf "${cloud_dir}"
    return 1
  fi
}

valid_processing_vm() {
  draw_line
  log_info "Memproses virt-install untuk VM '${yellow}${vm_name}${reset}'..."

  local iso_path="${dst_dir}/${vm_name}-cloud-init.iso"
  
  local virt_cmd=(
    virt-install -q
    --name "${vm_name}"
    --memory "${vm_mem}"
    --vcpus "${vm_cpu}"
    --import
    --disk "path=${vm_disk1},format=qcow2"
  )

  if [[ -f "${iso_path}" ]]; then
    virt_cmd+=(--disk "path=${iso_path},device=cdrom")
  fi

  if [[ ${#disk_extended[@]} -gt 0 ]]; then
    virt_cmd+=("${disk_extended[@]}")
  fi

  virt_cmd+=(
    --osinfo "detect=on,name=${osfinal}"
    --network "bridge=${vm_if_select}"
    --noautoconsole
  )

  if "${virt_cmd[@]}"; then
    log_success "Proses virt-install berhasil dikirim."
    virsh autostart "${vm_name}" >/dev/null 2>&1
    return 0
  else
    log_fail "Gagal menjalankan virt-install!"
    return 1
  fi
}

valid_final_vm() {
  draw_line
  if virsh list --all --name | grep -qwF -- "${vm_name}"; then
    log_success "VM ${yellow}${vm_name}${reset} BERHASIL DIBUAT!"
    virsh_check=$(virsh list --all | grep -w "${vm_name}")
    echo -e "  ${bold}${virsh_check}${reset}"
  else
    log_fail "Gagal membuat VM! Periksa log 'journalctl -u libvirtd -xe'."
  fi
}

run_create_vm_wizard() {
  valid_name
  valid_mem
  valid_cpu
  valid_primary_disk || return 1
  valid_extended_disk
  valid_cloud_init || return 1
  valid_processing_vm || return 1
  valid_final_vm
}

run_create_vm() {
  show_banner
  echo -e "${bold}${yellow}>>> WIZARD PEMBUATAN VIRTUAL MACHINE <<<${reset}\n"
  local start_time
  start_time="$(date '+%Y-%m-%d %H:%M:%S')"
  mkdir -p "${log_dir}" 2>/dev/null

  {
    echo "[${start_time}] virtUI Pembuatan Virtual Machine"
    echo ""
  } >> "${vm_log_file}"

  run_create_vm_wizard 2>&1 | tee >(sed -u -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' >> "${vm_log_file}")

  sleep 0.5
  local end_time
  end_time="$(date '+%Y-%m-%d %H:%M:%S')"

  {
    echo ""
    echo "[${end_time}] Complete: virtUI Pembuatan Virtual Machine"
  } >> "${vm_log_file}"
  pause
}

# ==========================================
# MAIN MENU LOOP
# ==========================================
main_menu() {
  while true; do
    show_banner
    echo -e "  ${bold}PILIH MENU UTAMA:${reset}\n"
    echo -e "   [${cyan}1${reset}] Pengecekan Sistem & Dependensi (Environment Check)"
    echo -e "   [${cyan}2${reset}] Buat Virtual Machine Baru (Create VM)"
    echo -e "   [${cyan}3${reset}] Manajemen Log System & VM (View Logs)"
    echo -e "   [${cyan}0${reset}] Keluar (Exit)"
    echo ""
    draw_line
    read -e -p "  Masukkan pilihan [0-3]: " opt
    case $opt in
      1)
        run_system_checks
        ;;
      2)
        run_create_vm
        ;;
      3)
        view_log_menu
        ;;
      0)
        echo -e "\n  ${yellow}Sampai Jumpa, Terima kasih! ${reset}\n"
        exit 0
        ;;
      *)
        log_fail "Pilihan tidak valid!"
        sleep 1
        ;;
    esac
  done
}

main_menu