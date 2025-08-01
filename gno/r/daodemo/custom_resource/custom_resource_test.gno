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
		res := daoPrivate.Core.Resources.Get("Hello")
		if res == nil {
			t.Fatal("Expected 'Hello' resource to be registered")
		}
		if res.Description != "Description" {
			t.Errorf("Expected resource description 'Description', got '%s'", res.Description)
		}
	})
}

func TestBlogResource(t *testing.T) {
	// Create test proposal
	req := daokit.ProposalRequest{
		Title:       "Add new blog post",
		Description: "Adding an important announcement",
		Action:      NewPostAction("Test Title", "Test Content"),
	}

	t.Run("Test proposal creation", func(t *testing.T) {
		Propose(nil, req)
		if daoPrivate.Core.Proposals.Tree.Size() != 1 {
			t.Fatalf("Expected 1 proposal, got %d", daoPrivate.Core.Proposals.Tree.Size())
		}

		raw, exist := daoPrivate.Core.Proposals.Tree.Get("1")
		if !exist {
			t.Errorf("Expected Proposal '1' to exist")
		}
		prop := raw.(*daokit.Proposal)
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
		Vote(nil, 1, daocond.VoteYes) // member1
		Vote(nil, 1, daocond.VoteYes) // member2
		Vote(nil, 1, daocond.VoteYes) // member3

		// Execute the proposal
		Execute(nil, 1)

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
		Propose(nil, req)

		// Vote with only 2 members (50% - below 60% threshold)
		Vote(nil, 2, daocond.VoteYes) // member1
		Vote(nil, 2, daocond.VoteYes) // member2

		// Try to execute - should fail
		Execute(nil, 2)

		// Verify blog post was NOT created
		if len(myblog.Post) != 0 {
			t.Fatalf("Expected 0 posts after failed execution, got %d", len(myblog.Post))
		}
	})
}

func TestActionHandlers(t *testing.T) {
	t.Run("Test post handler execution", func(t *testing.T) {
		// Create test blog
		testBlog := Blog{}
		handler := NewPostHandler(&testBlog)

		// Verify handler kind
		if handler.Type() != ActionNewPostKind {
			t.Errorf("Expected kind '%s', got '%s'", ActionNewPostKind, handler.Type())
		}

		// Execute handler
		handler.Execute(&ActionNewPost{
			Title:   "Handler Test",
			Content: "Handler Content",
		})

		// Verify blog updated
		if len(testBlog.Post) != 1 {
			t.Fatalf("Expected 1 post after handler execution, got %d", len(testBlog.Post))
		}
		post := testBlog.Post[0]
		if post.Title != "Handler Test" {
			t.Errorf("Expected title 'Handler Test', got '%s'", post.Title)
		}
	})

	t.Run("Test invalid payload handling", func(t *testing.T) {
		testBlog := Blog{}
		handler := NewPostHandler(&testBlog)

		// should panic
		abort := revive(func() { handler.Execute("invalid payload") })
		if abort != "invalid action type" {
			t.Error("Expected panic with invalid payload")
		}
	})
}
