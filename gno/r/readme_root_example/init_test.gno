package readme_root_example

import "testing"

func TestInitRuns(t *testing.T) {
	if daoPrivate == nil {
		t.Fatal("init did not build the DAO")
	}
}
