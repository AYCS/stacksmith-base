BITNAMI_PREFIX=/opt/bitnami
UPDATE_SERVER="https://container.checkforupdates.com"
CURL_ARGS="-sLf --connect-timeout 3"

print_welcome_page() {
  if [ -n "$BITNAMI_APP_NAME" ]; then
    print_image_welcome_page
  elif [ -n "$STACKSMITH_STACK_ID" ]; then
    print_stacksmith_welcome_page
  fi
}

check_for_updates() {
  if [ -z "$DISABLE_UPDATE_CHECK" ]; then
    if [ -n "$BITNAMI_APP_NAME" ]; then
      check_for_image_updates
    elif [ -n "$STACKSMITH_STACK_ID" ]; then
      check_for_stack_updates
    fi
  fi
}

# Prints the welcome page for this Bitnami Docker image
print_image_welcome_page() {
  GITHUB_PAGE=https://github.com/bitnami/bitnami-docker-${BITNAMI_APP_NAME}
cat << EndOfMessage

  *** Welcome to the ${BITNAMI_APP_NAME} image ***
  *** Brought to you by Bitnami ***
  *** More information: ${GITHUB_PAGE} ***
  *** Issues: ${GITHUB_PAGE}/issues ***

EndOfMessage
}

# Prints the welcome page for this Stacksmith stack
print_stacksmith_welcome_page() {
  STACKSMITH_URL="https://stacksmith.bitnami.com"
  STACKSMITH_STACK_URL="$STACKSMITH_URL/dashboard/stacks/$STACKSMITH_STACK_ID"

  if [ "$STACKSMITH_STACK_PRIVATE" ]; then
    MSG1="Go to $STACKSMITH_STACK_URL to manage your stack."
  else
    MSG1="This stack was created anonymously."
    MSG2="Sign up for a free account at $STACKSMITH_URL to manage and regenerate your stacks."
  fi

  cat << EndOfMessage

  *** Welcome to your $STACKSMITH_STACK_NAME container! ***
  *** Brought to you by Bitnami. ***
  *** $MSG1 ***
  *** $MSG2 ***

EndOfMessage
}

detect_cloud() {
  local CLOUD=unknown
  if curl $CURL_ARGS -o /dev/null http://169.254.169.254/latest/meta-data/; then
    CLOUD=aws
  elif curl $CURL_ARGS -o /dev/null http://169.254.169.254/0.1/meta-data/; then
    CLOUD=gce
  fi
  echo $CLOUD
}

detect_platform() {
  local PLATFORM=unknown
  if curl $CURL_ARGS -o /dev/null http://$(curl $CURL_ARGS http://169.254.169.254/latest/meta-data/hostname):51678/v1/metadata; then
    PLATFORM=ecs
  elif nc -z $KUBERNETES_SERVICE_HOST $KUBERNETES_SERVICE_PORT 2>/dev/null; then
    PLATFORM=kubernetes
  elif [ -n "$CHE_API" ]; then
    # CHE_API is set by Eclipse Che and Codenvy as of version 5.0.0-M8
    if [ "$CHE_API" == "https://codenvy.io/api" ]; then
      PLATFORM=codenvy
    else
      PLATFORM=che
    fi
  fi
  echo $PLATFORM
}

# Checks for any updates for this Stacksmith stack
check_for_stack_updates() {
  ORIGIN=${BITNAMI_CONTAINER_ORIGIN:-stacksmith}
  CLOUD=${BITNAMI_CONTAINER_CLOUD:-$(detect_cloud)}
  PLATFORM=${BITNAMI_CONTAINER_PLATFORM:-$(detect_platform)}

  RESPONSE=$(curl -s --connect-timeout 20 \
    --cacert /opt/bitnami/updates-ca-cert.pem \
    "$UPDATE_SERVER/api/v1?image=$STACKSMITH_STACK_ID&origin=$ORIGIN&cloud=$CLOUD&platform=$PLATFORM" \
    -w "|%{http_code}")

  STATUS=$(echo $RESPONSE | cut -d '|' -f 2)

  ACTION="go to https://stacksmith.bitnami.com/dashboard/stacks/"
  REGENERATE_ACTION="$ACTION$STACKSMITH_STACK_ID to regenerate"
  RECREATE_ACTION="${ACTION}new to create a new stack"

  if [ -z "$STACKSMITH_STACK_PRIVATE" ]; then
    # Can't regenerate if it's an anonymous stack
    REGENERATE_ACTION=$RECREATE_ACTION
  fi

  OUTDATED_MSG="Updates available"
  VULNERABLE_MSG="Your stack is vulnerable"

  if [ "$STATUS" = "200" ]; then
    COLOR="\e[0;30;42m"
    MSG="Your stack is up to date!"
  elif [ "$STATUS" = "201" ]; then
    COLOR="\e[0;30;43m"
    MSG="$OUTDATED_MSG: $REGENERATE_ACTION"
  elif [ "$STATUS" = "204" ]; then
    COLOR="\e[0;30;43m"
    MSG="$OUTDATED_MSG: $RECREATE_ACTION"
  elif [ "$STATUS" = "426" ]; then
    COLOR="\e[0;37;41m"
    MSG="$VULNERABLE_MSG: $REGENERATE_ACTION"
  elif [ "$STATUS" = "423" ]; then
    COLOR="\e[0;37;41m"
    MSG="$VULNERABLE_MSG: $RECREATE_ACTION"
  fi

  if [ "$MSG" ]; then
    printf "\n$COLOR*** $MSG ***\e[0m\n\n"
  fi
}

# Checks for any updates for this Bitnami Docker image
check_for_image_updates() {
  UPDATE_SERVER="https://container.checkforupdates.com"
  ORIGIN=${BITNAMI_CONTAINER_ORIGIN:-DHR}
  CLOUD=${BITNAMI_CONTAINER_CLOUD:-$(detect_cloud)}
  PLATFORM=${BITNAMI_CONTAINER_PLATFORM:-$(detect_platform)}

  case "$PLATFORM" in
    che|codenvy ) DISABLE_UPDATE_MESSAGE=1 ;; # disable update message displayed when running on che
  esac

  RESPONSE=$(curl -s --connect-timeout 20 \
    --cacert $BITNAMI_PREFIX/updates-ca-cert.pem \
    "$UPDATE_SERVER/api/v1?image=$BITNAMI_APP_NAME&version=$BITNAMI_IMAGE_VERSION&origin=$ORIGIN&cloud=$CLOUD&platform=$PLATFORM" \
    -w "|%{http_code}")

  VERSION=$(echo $RESPONSE | cut -d '|' -f 1)
  if [[ ! $VERSION =~ [0-9.-] ]]; then
    return
  fi

  STATUS=$(echo $RESPONSE | cut -d '|' -f 2)

  if [ "$STATUS" = "200" ]; then
    COLOR="\e[0;30;42m"
    MSG="Your container is up to date!"
  elif [ "$STATUS" = "201" ]; then
    COLOR="\e[0;30;43m"
    MSG="New version available: run docker pull bitnami/$BITNAMI_APP_NAME:$VERSION to update."
  fi

  if [ -z "$DISABLE_UPDATE_MESSAGE" -a "$MSG" ]; then
    printf "\n$COLOR*** $MSG ***\e[0m\n\n"
  fi
}
