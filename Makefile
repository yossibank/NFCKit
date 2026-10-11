.PHONY: setup format lint test

setup:
	brew bundle
	mint bootstrap
	pre-commit install

format:
	mint run swiftformat .

lint:
	mint run swiftformat --lint .

test:
	swift test
