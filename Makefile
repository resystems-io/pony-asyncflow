all: build/pony-asyncflow

build/pony-asyncflow:
	@ninja

clean:
	@ninja -t clean
	@rm -rf build

.PHONY: clean all
