#! /bin/bash

 # Script For Building Android arm64 Kernel
 #
 # Copyright (c) 2018-2020 Panchajanya1999 <rsk52959@gmail.com>
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #      http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #

#Kernel building script

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

##------------------------------------------------------##
##----------Basic Informations, COMPULSORY--------------##

# The defult directory where the kernel should be placed
KERNEL_DIR=$PWD

# The name of the Kernel, to name the ZIP
ZIPNAME="[SDClang]Kara"

# The name of the device for which the kernel is built
MODEL="Redmi 7"

# The codename of the device
DEVICE="onclite"

# The defconfig which should be used. Get it from config.gz from
# your device or check source
DEFCONFIG=onclite-perf_defconfig

# Specify compiler. 
# 'clang' or 'gcc'
COMPILER=clang

# Clean source prior building. 1 is NO(default) | 0 is YES
INCREMENTAL=1

# Push ZIP to Telegram. 1 is YES | 0 is NO(default)
PTTG=1
	if [ $PTTG = 1 ]
	then
		# Set Telegram Chat ID
		CHATID="-1001851989071"
	fi

# Generate a full DEFCONFIG prior building. 1 is YES | 0 is NO(default)
DEF_REG=0

# Build dtbo.img (select this only if your source has support to building dtbo.img)
# 1 is YES | 0 is NO(default)
BUILD_DTBO=1

# Sign the zipfile
# 1 is YES | 0 is NO
SIGN=1

# Silence the compilation
# 1 is YES(default) | 0 is NO
SILENCE=0

# Debug purpose. Send logs on every successfull builds
# 1 is YES | 0 is NO(default)
LOG_DEBUG=0

##------------------------------------------------------##
##---------Do Not Touch Anything Beyond This------------##

# Check if we are using a dedicated CI ( Continuous Integration ), and
# set KBUILD_BUILD_VERSION and KBUILD_BUILD_HOST and CI_BRANCH

## Set defaults first
DISTRO=$(cat /etc/issue)
KBUILD_BUILD_HOST=Teyvat
CI_BRANCH=$(git rev-parse --abbrev-ref HEAD)
export KBUILD_BUILD_HOST CI_BRANCH
## Check for CI
if [ -n "$CI" ]
then
	if [ -n "$CIRCLECI" ]
	then
		export KBUILD_BUILD_VERSION=$CIRCLE_BUILD_NUM
		export KBUILD_BUILD_HOST="CircleCI"
		export CI_BRANCH=$CIRCLE_BRANCH
	fi
	if [ -n "$DRONE" ]
	then
		export KBUILD_BUILD_VERSION=$DRONE_BUILD_NUMBER
		export CI_BRANCH=$DRONE_BRANCH
	else
		echo "Not presetting Build Version"
	fi
fi

#Check Kernel Version
KERVER=$(make kernelversion)


# Set a commit head
COMMIT_HEAD=$(git log --oneline -1)

# Set Date 
DATE=$(TZ=Asia/Jakarta date +%y%m%d-%H%M)

#Now Its time for other stuffs like cloning, exporting, etc

 clone() {
	echo " "
	msg "|| Cloning Clang ||"
	git clone --depth=1 https://github.com/ZyCromerZ/SDClang clang-llvm --no-tags --single-branch
	msg "|| Cloning binutils ||"
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth=1 --single-branch --branch="lineage-19.1" gcc64
	git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 --depth=1 --single-branch --branch="lineage-19.1" gcc32
		# Toolchain Directory defaults to clang-llvm
	TC_DIR=$KERNEL_DIR/clang-llvm
	GCC64_DIR=$KERNEL_DIR/gcc64
	GCC32_DIR=$KERNEL_DIR/gcc32

	msg "|| Cloning Anykernel ||"
	git clone --depth 1 --no-single-branch https://github.com/Risti699/AnyKernel3.git -b master
}

##------------------------------------------------------##

exports() {
	export KBUILD_BUILD_USER="PapiLer"
	export ARCH=arm64
	export SUBARCH=arm64
	export token=5748449722:AAF8DDlYIxcZ4fhyS-Nal7NurbicxNnAZBU

		KBUILD_COMPILER_STRING=$("$TC_DIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
		PATH=$TC_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:$PATH
		export LD_LIBRARY_PATH=$TC_DIR/lib64:$LD_LIBRARY_PATH
		

	export PATH KBUILD_COMPILER_STRING 
	export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
	export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"
	PROCS=$(nproc --all)
	export PROCS
}

##---------------------------------------------------------##

tg_post_msg() {
	curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
	-d "disable_web_page_preview=true" \
	-d "parse_mode=html" \
	-d text="$1"

}

##----------------------------------------------------------------##

tg_post_build() {
	#Post MD5Checksum alongwith for easeness
	MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

	#Show the Checksum alongwith caption
	curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
	-F chat_id="$2"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=html" \
	-F caption="$3 | <code>Build Number : </code><b>$DRONE_BUILD_NUMBER</b>"  
}

##----------------------------------------------------------##

build_kernel() {
	if [ $INCREMENTAL = 0 ]
	then
		msg "|| Cleaning Sources ||"
		make clean && make mrproper && rm -rf out
	fi

	if [ "$PTTG" = 1 ]
 	then
		tg_post_msg "<b>🔨 $KBUILD_BUILD_VERSION CI Build Triggered</b>%0A<b>Kernel Version : </b><code>$KERVER</code>%0A<b>Date : </b><code>$(TZ=Asia/Jakarta date)</code>%0A<b>Compiler Used : </b><code>$KBUILD_COMPILER_STRING</code>%0a<b>Branch : </b><code>$CI_BRANCH</code>%0A<b>HEAD : </b><a href='$DRONE_COMMIT_LINK'>$COMMIT_HEAD</a>" "$CHATID"
	fi

	make O=out $DEFCONFIG CC=clang
	if [ $DEF_REG = 1 ]
	then
		cp .config arch/arm64/configs/$DEFCONFIG
		git add arch/arm64/configs/$DEFCONFIG
		git commit -m "$DEFCONFIG: Regenerate
						This is an auto-generated commit"
	fi

	BUILD_START=$(date +"%s")
	
	
	if [ $SILENCE = "1" ]
	then
		MAKE+=( -s )
	fi

	msg "|| Started Compilation ||"
	make -j"$PROCS" O=out CC=clang LD=ld.lld LLVM_IAS=1 AR=llvm-ar OBJDUMP=llvm-objdump STRIP=llvm-strip OBJCOPY=llvm-objcopy CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi-
		BUILD_END=$(date +"%s")
		DIFF=$((BUILD_END - BUILD_START))

		if [ -f "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb ] 
	    then
	    	msg "|| Kernel successfully compiled ||"
	    	if [ $BUILD_DTBO = 1 ]
			then
				msg "|| Building DTBO ||"
				python2 "$KERNEL_DIR/scripts/ufdt/libufdt/utils/src/mkdtboimg.py" \
					create "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" --page_size=4096 "$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm6150-idp-overlay.dtbo"
			fi
				gen_zip
		else
			if [ "$PTTG" = 1 ]
 			then
				tg_post_msg "<b>❌ Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>" "$CHATID"
			fi
		fi
	
}

##--------------------------------------------------------------##

gen_zip() {
	msg "|| Zipping into a flashable zip ||"
	mv "$KERNEL_DIR"/out/arch/arm64/boot/Image.gz-dtb AnyKernel3/Image.gz-dtb
	if [ $BUILD_DTBO = 1 ]
	then
		mv "$KERNEL_DIR"/out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
	fi
	cd AnyKernel3 || exit
	zip -r9 $ZIPNAME-$DEVICE-"$DATE" * -x .git README.md

	## Prepare a final zip variable
	ZIP_FINAL="$ZIPNAME-$DEVICE-$DATE.zip"
	if [ "$PTTG" = 1 ]
 	then
		tg_post_build "$ZIP_FINAL" "$CHATID" "✅ Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
	fi
	cd ..
	rm -rf AnyKernel3
}

clone
exports
build_kernel

if [ $LOG_DEBUG = "1" ]
then
	tg_post_build "error.log" "$CHATID" "Debug Mode Logs"
fi

##----------------*****-----------------------------##
