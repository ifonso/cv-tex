.PHONY: all watch clean

all:
	latexmk

watch:
	latexmk -pvc

clean:
	latexmk -C
	rm -rf build
