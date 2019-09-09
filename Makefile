documentation:
	@jazzy \
		--author "Ranganath Atreya" \
		--github_url https://github.com/ratreya/lipika-engine \
		--min-acl public \
		--theme fullwidth \
		--output ./docs \
		--module LipikaEngine_OSX \
		--module-version 2.1 \
		--xcodebuild-arguments -project,LipikaEngine.xcodeproj,-scheme,LipikaEngine_OSX \
		--readme ./.github/README.md
	@rm -rf ./build
