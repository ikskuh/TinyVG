TARGETS=win-x64 linux-x64 linux-arm64 linux-arm

default:
	dotnet build -r linux-x64 -p:PublishSingleFile=true -p:SelfContained=true

publish: $(TARGETS)

$(TARGETS):
	dotnet publish -r $@ -c Release -p:PublishSingleFile=true -p:SelfContained=true
	mkdir -p "release/$@"
	cp -r bin/Release/net5.0/$@/publish/* "release/$@/"

.PHONY: $(TARGETS)
.SUFFIXES: