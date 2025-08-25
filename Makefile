CHECK_ENV = dart run scripts/check_env.dart
FIX_BIGPICTURE = dart run scripts/fix_bigpicture.dart

.PHONY: all check_env apk desktop-presence desktop-presence-windows desktop-presence-linux desktop-presence-macos

all: check_env
	@echo "Use 'make apk', 'make desktop-presence', or platform-specific targets"
	@echo "Platform-specific targets: desktop-presence-windows, desktop-presence-linux, desktop-presence-macos"

check_env:
	$(CHECK_ENV)

apk: check_env
	cd apps/mobile_app && \
	flutter pub get && \
	cd ../../ && \
	$(FIX_BIGPICTURE) && \
	cd apps/mobile_app && \
	flutter pub run flutter_launcher_icons && \
	flutter build apk --release

desktop-presence: check_env
	cd apps/presence && \
	npm install && \
	npm run build

desktop-presence-windows: check_env
	cd apps/presence && \
	npm install && \
	npm run build -- --win

desktop-presence-linux: check_env
	cd apps/presence && \
	npm install && \
	npm run build -- --linux

desktop-presence-macos: check_env
	cd apps/presence && \
	npm install && \
	npm run build -- --mac
