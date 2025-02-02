#!/bin/bash
#ls -d -- */
##### command :
cur_path=`pwd`
bs=$1
######## SET PATHs ############################
pid=`echo $$`;echo "==============================="
echo "pid:$pid";echo "===============================";

if [ "$bs" = "538.imagick_r_train" ]; then
  #: '
  benchmark_path="/home/$username/cpu2017/benchspec/CPU/538.imagick_r/src"
  cd $benchmark_path
  mkdir $bs"-compiled-W-clang."$pid
  echo "  1) Compile $bs original code with clang-16 ..."
  for d in */ ; do
    echo "$d"
    [ -L "${d%/}" ] && continue
    for FILE in $d*;
    do
      if [[ $FILE == *.c ]]; then
        echo $FILE;
        name=${FILE::-2}
        while IFS='/' read -ra ADDR; do
           fileName=${ADDR[1]}
           folderName=${ADDR[0]}
           echo "fileName: " $fileName
           echo "folderName: " $folderName
        done <<< "$name"
        clang-16 -std=c99 -m64 -DSPEC -DNDEBUG -I. -DSPEC_AUTO_SUPPRESS_OPENMP -gmlt -O3 -fdebug-info-for-profiling -march=native -fno-unsafe-math-optimizations -no-pie -fcommon -DSPEC_LP64 $FILE -S -emit-llvm -o $bs"-compiled-W-clang."$pid/$folderName"-"$fileName".ll"
      fi
    done
    echo ""
    #cd ..
  done
  cd $bs"-compiled-W-clang."$pid
  clang-16 -std=c99 -m64 -DSPEC -DNDEBUG -I. -DSPEC_AUTO_SUPPRESS_OPENMP -g -O3 -fdebug-info-for-profiling -march=native -fno-unsafe-math-optimizations -no-pie -fcommon -DSPEC_LP64 image_validator-ImageValidator.ll -c
  clang-16 -std=c99 -m64 -DSPEC -DNDEBUG -I. -DSPEC_AUTO_SUPPRESS_OPENMP -g -O3 -fdebug-info-for-profiling -march=native -fno-unsafe-math-optimizations -no-pie -fcommon -DSPEC_LP64 image_validator-ImageValidator.o -lm -o imagevalidate_538

  mv image_validator-ImageValidator.o ../
  mv image_validator-ImageValidator.ll ../
  clang-16 -std=c99 -m64 -DSPEC -DNDEBUG -I. -DSPEC_AUTO_SUPPRESS_OPENMP -gmlt -O3 -fdebug-info-for-profiling -march=native -fno-unsafe-math-optimizations -no-pie -fcommon -DSPEC_LP64  *.ll -c
  clang-16 -std=c99 -m64 -DSPEC -DNDEBUG -I. -DSPEC_AUTO_SUPPRESS_OPENMP -gmlt -O3 -fdebug-info-for-profiling -march=native -fno-unsafe-math-optimizations -no-pie -fcommon -DSPEC_LP64  *.o -lm  -o $bs
fi
