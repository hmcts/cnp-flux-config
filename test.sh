#loadSecret "AZURE_SERVICE_BUS_CONNECTION_STRING" ${tamtam_VAULT_NAME} "tamtam-servicebus-connection-string-tf"
#export AZURE_SERVICE_BUS_CONNECTION_STRING=Endpoint=sb://tamtam-sb-preview.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=3123KpNQHFw/MGsRanSH8I+09PW/31SbINOPxUw87w9Fh=
export AZURE_SERVICE_BUS_CONNECTION_STRING=Endpoint=sb://tamtams.windows.net/;SharedAccessKeyName=SendAndListenSharedAccessKey;SharedAccessKey=3tvwoHXvULx+gTQgshv+ASbAv+CTIbmZEwqs4l+W3l5=
#loadSecret "SYSTEMUPDATE_USERNAME" ${tamtam_VAULT_NAME} "tamtam-tamtam-systemupdate-user"
#loadSecret "SYSTEMUPDATE_USERNAME" ${tamtam_VAULT_NAME} "example@gmail.com"
export SYSTEMUPDATE_USERNAME=example@hmcts.net