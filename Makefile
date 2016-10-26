IMAGE_FLAVORS := ubuntu/12.04 ubuntu/14.04 ubuntu/16.04 debian/wheezy minideb/jessie
GCLOUD_PROJECT := stacksmith-images
GCLOUD_SERVICE_KEY :=

.PHONY: all build cache push

all: build

build:
	@for f in $(IMAGE_FLAVORS); do \
		distro=$$(echo "$$f" | cut -d'/' -f1) ; \
		release=$$(echo "$$f" | cut -d'/' -f2) ; \
		revision=$$(cat $$distro/$$release/REVISION) ; \
		if [ $(DEV_BUILD) ]; then revision=DEV; fi ; \
		docker build --rm=false -t gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release-r$$revision -f $$distro/$$release/Dockerfile . && \
		echo "FROM gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release-r$$revision\n$$(cat $$distro/$$release/buildpack/Dockerfile)" | \
		docker build --rm=false -t gcr.io/$(GCLOUD_PROJECT)/$$distro-buildpack:$$release-r$$revision - ; \
	done

push: build
	@if [ -n "$(GCLOUD_SERVICE_KEY)" ]; then \
		echo $(GCLOUD_SERVICE_KEY) | base64 --decode > ${HOME}/gcloud-service-key.json ; \
		gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json ; \
		for f in $(IMAGE_FLAVORS); do \
			distro=$$(echo "$$f" | cut -d'/' -f1) ; \
			release=$$(echo "$$f" | cut -d'/' -f2) ; \
			revision=$$(cat $$distro/$$release/REVISION) ; \
			if [ $(DEV_BUILD) ]; then revision=DEV; fi ; \
			gcloud docker -- push gcr.io/$(GCLOUD_PROJECT)/$$distro:$$release-r$$revision ; \
			gcloud docker -- push gcr.io/$(GCLOUD_PROJECT)/$$distro-buildpack:$$release-r$$revision ; \
		done ; \
	fi
