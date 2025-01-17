duvet: | duvet_extract duvet_report

duvet_extract:
	rm -rf compliance
	$(foreach file, $(shell find specification -name '*.md'), duvet extract -o compliance -f MARKDOWN $(file);)

duvet_report:
	duvet \
		report \
		--spec-pattern "compliance/**/*.toml" \
		--source-pattern "DynamoDbEncryption/dafny/**/*.dfy" \
		--source-pattern "DynamoDbEncryption/dafny/**/*.smithy" \
		--source-pattern "DynamoDbEncryption/runtimes/java/src/main/java/**/*.java" \
		--html specification_compliance_report.html
