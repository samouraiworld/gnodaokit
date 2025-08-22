package basedao

import (
	"time"

	"gno.land/p/demo/ufmt"
	"gno.land/p/moul/md"
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

// FormatDateTimeWithUTCOffset formats a time.Time object as a string with UTC offset.
func FormatDateTimeWithUTCOffset(t time.Time) string {
	_, offsetSeconds := t.Zone()
	hours := offsetSeconds / 3600
	minutes := (offsetSeconds % 3600) / 60
	sign := "+"
	if hours < 0 || minutes < 0 {
		sign = "-"
		hours = -hours
		minutes = -minutes
	}
	return ufmt.Sprintf("%s UTC%s%02d:%02d",
		t.Format("2006-01-02 15:04:05"),
		sign, hours, minutes)
}
