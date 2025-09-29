package custom_resource

import (
	"testing"

	"gno.land/p/samcrew/daocond"
	"gno.land/p/samcrew/daokit"
)

func TestDAOInitialization(t *testing.T) {
	t.Run("Test member initialization", func(t *testing.T) {
		membersCount := daoPrivate.Members.MembersCount()
		if membersCount != 4 {
			t.Fatalf("Expected 4 members, got %d", membersCount)
		}
	})

	t.Run("Test role initialization", func(t *testing.T) {
		roles := daoPrivate.Members.GetRoles()
		expectedRoles := []string{"Role"}
		if len(roles) != len(expectedRoles) {
			t.Fatalf("Expected %d roles, got %d", len(expectedRoles), len(roles))
		}
		for i, role := range roles {
			if role != expectedRoles[i] {
				t.Fatalf("Expected role %s, got %s", expectedRoles[i], role)
			}
		}
	})

	t.Run("Test custom resource registration", func(t *testing.T) {
		res := daoPrivate.Core.Resources.Get(ActionNewPostKind)
		if res == nil {
			t.Fatal("Expected '%s' resource to be registered", ActionNewPostKind)
		}
		if res.Description != "Description" {
			t.Errorf("Expected resource description 'Description', got '%s'", res.Description)
		}
	})
}

func TestBlogResource(t *testing.T) {
	testing.SetRealm(testing.NewUserRealm("g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh"))

	action := NewPostAction("Test Title", "Test Content")
	// Create test proposal
	req := daokit.ProposalRequest{
		Title:       "Add new blog post",
		Description: "Adding an important announcement",
		Action:      action,
	}

	t.Run("Test proposal creation", func(t *testing.T) {
		Propose(cross, req)
		if daoPrivate.Core.Proposals.Tree.Size() != 4 {
			t.Fatalf("Expected 1 proposal, got %d", daoPrivate.Core.Proposals.Tree.Size())
		}

		prop := daoPrivate.Core.Proposals.GetProposal(4)
		if prop.Title != req.Title {
			t.Errorf("Expected title '%s', got '%s'", req.Title, prop.Title)
		}
	})

	t.Run("Test voting and execution", func(t *testing.T) {
		// Verify initial blog state
		if len(myblog.Post) != 0 {
			t.Fatalf("Expected 0 posts initially, got %d", len(myblog.Post))
		}

		// Vote with 3 members (meets 60% threshold of 4 members)
		Vote(cross, 4, daocond.VoteYes) // member1
		testing.SetRealm(testing.NewUserRealm("g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld65"))
		Vote(cross, 4, daocond.VoteYes) // member2
		testing.SetRealm(testing.NewUserRealm("g1q87ppukjx8mp7n70fal8ept6ajwr0dttafld64"))
		Vote(cross, 4, daocond.VoteYes) // member3

		// Execute the proposal
		Execute(cross, 4)

		// Verify blog post was created
		if len(myblog.Post) != 1 {
			t.Fatalf("Expected 1 post after execution, got %d", len(myblog.Post))
		}

		post := myblog.Post[0]
		if post.Title != "Test Title" {
			t.Errorf("Expected title 'Test Title', got '%s'", post.Title)
		}
		if post.Content != "Test Content" {
			t.Errorf("Expected content 'Test Content', got '%s'", post.Content)
		}
	})

	t.Run("Test insufficient votes", func(t *testing.T) {
		// Reset blog
		myblog = Blog{}

		// Create new proposal
		req.Action = NewPostAction("Should Not Create", "This shouldn't appear")
		Propose(cross, req)

		// should panic
		abort := revive(func() { Execute(cross, 2) })
		if abort != "proposal condition is not met" {
			t.Fatal("expected execute to panic, but it did not")
		}

		// Verify blog post was NOT created
		if len(myblog.Post) != 0 {
			t.Fatalf("Expected 0 posts after failed execution, got %d", len(myblog.Post))
		}
	})
}
