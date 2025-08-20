package custom_resource

import (
	"std"
	"time"
)

type Post struct {
	Title   string
	Content string
	Created time.Time
	Creator std.Address // Address of the creator
}

type Blog struct {
	Post []Post
}

func (a *Blog) NewPost(title string, content string) {
	newPost := Post{
		Title:   title,
		Content: content,
		Created: time.Now(),
		Creator: std.PreviousRealm().Address(),
	}
	a.Post = append(a.Post, newPost)
}

func (a *Blog) Render() string {
	s := ""
	if len(a.Post) == 0 {
		return "No post available"
	}
	for i := 0; i < len(a.Post); i++ {
		s += "## " + a.Post[i].Title + "\n\n"
		s += " " + a.Post[i].Content + "\n\n"
		s += a.Post[i].Created.Format("15h04 02/01/2006")
		s += " - " + a.Post[i].Creator.String() + "\n\n"
		s += "---\n"
	}
	return s
}
