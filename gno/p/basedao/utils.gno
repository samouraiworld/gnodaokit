package basedao

import (
	"gno.land/p/demo/ufmt"
	"gno.land/p/mason/md"
)

// TruncateMiddle truncates a string to a maximum length, adding "..." in the middle if it exceeds the limit.
func TruncateMiddle(s string, max ...int) string {
	defMax := 12
	if len(max) > 0 {
		defMax = max[0]
	}
	runes := []rune(s)
	if len(runes) <= defMax {
		return s
	}
	if defMax <= 3 {
		return string(runes[:defMax])
	}
	half := (defMax - 3) / 2
	return ufmt.Sprintf("%s...%s", string(runes[:half]), string(runes[len(runes)-half:]))
}

// RenderAddressLink formats an address as a clickable link in Markdown.
func RenderAddressLink(addr string) string {
	return md.Link(TruncateMiddle(addr), ufmt.Sprintf("/u/%s", addr))
}
