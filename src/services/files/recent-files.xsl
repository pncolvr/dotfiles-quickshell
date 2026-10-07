<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"
    xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
  <xsl:output method="text" encoding="UTF-8"/>
  <xsl:template match="/">
    <xsl:if test="not(xbel)">
      <xsl:message terminate="yes">Expected an XBEL document.</xsl:message>
    </xsl:if>
    <xsl:for-each select="xbel/bookmark[not(info/metadata[@owner='http://freedesktop.org']/bookmark:private)]">
      <!-- Valid file URIs escape whitespace; keep the record delimiter unambiguous. -->
      <xsl:if test="not(contains(@href, '&#9;') or contains(@href, '&#10;') or contains(@href, '&#13;'))">
        <xsl:value-of select="@href"/><xsl:text>&#9;</xsl:text>
        <xsl:value-of select="normalize-space(@modified)"/><xsl:text>&#9;</xsl:text>
        <xsl:value-of select="normalize-space(@visited)"/><xsl:text>&#9;</xsl:text>
        <xsl:value-of select="normalize-space(@added)"/><xsl:text>&#9;</xsl:text>
        <xsl:value-of select="normalize-space(info/metadata[@owner='http://freedesktop.org']/mime:mime-type/@type)"/>
        <xsl:text>&#10;</xsl:text>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>
</xsl:stylesheet>
