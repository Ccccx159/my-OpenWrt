#!/bin/bash

root_dir=$(pwd) # 保存当前目录
git submodule update --init --recursive
rm ${root_dir}/env.sh -rf
# 获取依赖，并更新
line_no=$(grep -wn "安装编译依赖" ${root_dir}/lede/README.md | awk -F ':' '{print $1}')
env_write="false"
while :
do
    # echo -e "pos_end is ${pos_end}"
    line=$(sed -n "${line_no}, ${line_no}p" ${root_dir}/lede/README.md)
    # echo -e "line is ${line}"
    if [[ ${line} =~ (.*\`+$) ]]; then
        break
    fi
    if [[ ${line} =~ (.*\`+bash) ]]; then
        env_write="true"
        let line_no+=1
        continue
    fi
    if [[ "${env_write}" == "true" ]]; then
        echo -e "${line}" >> ${root_dir}/env.sh
    fi
    let line_no+=1
done

cat ${root_dir}/env.sh
source ${root_dir}/env.sh

mkdir -p ${root_dir}/artifacts/firmware

sed -i '$a src-git tencent_ddns https://github.com/Tencent-Cloud-Plugins/tencentcloud-openwrt-plugin-ddns.git' ${root_dir}/lede/feeds.conf.default
sed -i '$a src-git openclash https://github.com/vernesong/OpenClash.git' ${root_dir}/lede/feeds.conf.default
${root_dir}/lede/scripts/feeds update -a
${root_dir}/lede/scripts/feeds install -a


# 1.列举当前目录下的所有 .config.* 文件，并保存在数组中
config_files=$(ls ${root_dir}/.config.*)
for conf in ${config_files[@]}
do
    echo "开始编译 ${conf} ..."
    # # 2.复制 .config.* 文件到 openwrt 源码根目录下
    cp ${conf} ${root_dir}/lede/.config
    # # 3.编译 openwrt
    make -C lede download -j$(nproc) || exit 1
    echo -e "make download success"
    make -C lede -j$(nproc) || make -C lede -j1 V=s || exit 1
    echo -e "make success"
    cp -rf $(find ${root_dir}/lede/bin/targets -type f -name "openwrt-*.img.gz") ${root_dir}/artifacts/firmware
    make clean
done

