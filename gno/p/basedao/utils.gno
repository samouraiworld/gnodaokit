package basedao

func truncateMiddle(s string, max int) string {
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	if max <= 3 {
		return string(runes[:max])
	}
	half := (max - 3) / 2
	return string(runes[:half]) + "..." + string(runes[len(runes)-half:])
}

func displayAddressMD(addr string) string {
	return "[" + truncateMiddle(addr, 16) + "](/u/" + addr + ")"
}
