	sudo mkdir -p "catsaverpkg/Library/Screen Savers"
	mkdir -p catsaverpkg
	mkdir -p catsavercombopkg
	mkdir -p catsaverinst
	sudo cp -Rf build/Debug/CatSaver.saver catsaverinst/
	sudo chown -R root:wheel catsaverinst
	cd catsaverinst && sudo rm -f .DS_Store */.DS_Store */*/.DS_Store */*/*/.DS_Store && sudo cpio -o < ../catsaver_pkg.txt > ../catsaverpkg/Payload && sudo rm -f .DS_Store */.DS_Store */*/.DS_Store */*/*/.DS_Store && sudo mkbom . ../catsaverpkg/Bom && cd ..
	sudo cp -Rf Installer/PackageInfo catsaverpkg/PackageInfo
	cd catsaverpkg && sudo rm -Rf .DS_Store */.DS_Store */*/.DS_Store */*/*/.DS_Store && sudo xar -cjf ../catsaver-1.0.pkg . && cd ..
	sudo cp -Rf Installer/Resources catsavercombopkg/Resources
	sudo cp -f Installer/Distribution catsavercombopkg/Distribution
	sudo rm -Rf .DS_Store */.DS_Store */*/.DS_Store */*/*/.DS_Store && sudo productbuild --distribution Installer/Distribution --resources Resources --package-path "/Library/Screen Savers" catsavercombopkg.pkg
	sudo rm -Rf catsavercombopkg
	sudo rm  -Rf catsaverpkg
	sudo rm -Rf catsaverinst
    sudo rm -Rf catsaver-1.0.pkg
	mv catsavercombopkg.pkg catsaver-debug.pkg

