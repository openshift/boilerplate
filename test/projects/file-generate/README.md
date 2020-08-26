This is a dummy project used to test the `check-generate` make target for go operator (like in `openshift/golang-osd-operator`).

#### Projects main points
- This is an operator initialized with `operator-sdk v0.16` in order to have all the `make generate` commands working properly
- There are 2 dummy files (`src/test/test.go` and `src/test/subfolder/test.go`) containing basic generate commands which are tested/validated in the test case