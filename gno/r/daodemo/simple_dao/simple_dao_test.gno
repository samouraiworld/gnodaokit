package simple_dao

import "testing"

// `init()` function is executed by default from `basic_dao.gno`, hence the `membersCount != 4`.
// Refers to `basic_dao.gno` to understand the outcome of this test.
func TestInit(t *testing.T) {
	membersCount := daoPrivate.Members.MembersCount()
	if membersCount != 4 {
		t.Fatalf("Expected 4 members, got %d", membersCount)
	}

	roles := daoPrivate.Members.GetRoles()
	expectedRoles := []string{"admin", "public-relationships", "finance-officer"}
	if len(roles) != len(expectedRoles) {
		t.Fatalf("Expected %d roles, got %d", len(expectedRoles), len(roles))
	}
	for _, role := range roles {
		err := true
		for _, expectedRole := range expectedRoles {
			if role == expectedRole {
				err = false
				break
			}
		}
		if err {
			t.Fatalf("Expected roles %v, got %v", expectedRoles, roles)
		}
	}
}
