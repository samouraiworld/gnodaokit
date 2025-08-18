package basedao

import (
	"gno.land/p/demo/ufmt"
	"gno.land/p/mason/md"
)

// truncateMiddle truncates a string to a maximum length, adding "..." in the middle if it exceeds the limit.
func truncateMiddle(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	if max <= 3 {
		return string(runes[:max])
	}
	half := (max - 3) / 2
	return ufmt.Sprintf("%s...%s", string(runes[:half]), string(runes[len(runes)-half:]))
}

// renderAddressLink formats an address as a clickable link in Markdown.
func renderAddressLink(addr string) string {
	return md.Link(truncateMiddle(addr, 16), ufmt.Sprintf("/u/%s", addr))
}
