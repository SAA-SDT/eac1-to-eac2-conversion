<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:eac="urn:isbn:1-931666-33-4"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map"
    xmlns:xlink="http://www.w3.org/1999/xlink" exclude-result-prefixes="#all"
    version="3.0">
    
    <!-- XSLT3 conversion process to transform EAC-CPF 1.0 documents to EAC-CPF 2.0 -->
    
    <!-- to do:
        1) review if outline/level to list/list is output as expected;
        2) add a separate XSLT file to handle the sorting of elements, which would cut down on the file size of this one considerably?;
        2) add more options?;
    -->

    <xsl:output method="xml" encoding="UTF-8" indent="true"/>
    <xsl:mode on-no-match="shallow-copy"/>
    
    
    <!-- Global Parameters --> 
    <xsl:param name="eac-xmlns" select="'https://archivists.org/ns/eac/v2'" as="xs:string"/>  
    <xsl:param name="eac-xlmns-migration" select="'https://archivists.org/ns/eac/migration'" as="xs:string"/>
    <xsl:param name="default-cpf-type" select="'agent'" as="xs:string"/>
    <xsl:param name="default-empty-element-text" select="'***** WARNING: content is now required when this element is utilized in this way. Nothing to add, aside from this warning message, so please fix manually *****'" as="xs:string"/>
    <xsl:param name="default-empty-message" select="'This empty element would be invalid in the new EAC 2.0 data model. Because of that, the transformation is adding some extra structure to the output. Please review.'"/>
    <xsl:param name="retain-xlink-actuate-show-and-type" select="false()" as="xs:boolean"/>
    <xsl:param name="attempt-to-convert-to-geocoordinates" select="true()" as="xs:boolean"/>
    <xsl:param name="default-coordinate-system" select="''" as="xs:string"/>
    <!-- note, if changed (since we don't have an internationalization file), then the *message / *text / *name parameters should also be updated -->
    <xsl:param name="default-xml-lang" select="'eng'" as="xs:string"/>
    <xsl:param name="default-migration-event-type" select="'updated'" as="xs:string"/>
    <xsl:param name="default-migration-agent-name" select="'EAC-CPF 1.x to EAC 2.0 Migration Style Sheet (eac1-to-eac2.xsl)'" as="xs:string"/>
    <xsl:param name="default-migration-text" select="'EAC-CPF 1.x (urn:isbn:1-931666-33-4) instance migrated to EAC 2.0 (https://archivists.org/ns/eac/v2)'" as="xs:string"/>
    <xsl:param name="include-migration-maintenanceEvent" select="true()" as="xs:boolean"/>
    <!-- by default, if the above parameter is true, then when a new maintenanceEvent is added, all maintenanceEvents will be sorted in descending order. change to 'ascending' if you would prefer the reverse. -->
    <xsl:param name="maintenanceEvent-sort-order" select="'descending'" as="xs:string"/>
    
    <!-- by default, the output will be associated with the RNG schema. You can switch to 'xsd', or pass 'xsd' to the transformation process, to associate your output files with the XSD schema instead of the RNG schema -->
    <xsl:param name="schema-output-version" select="'rng'" as="xs:string"/>

    <!-- replace with Staatsbibliothek zu Berlin URL path once the files have been migrated -->
    <xsl:param name="schema-path" select="'https://raw.githubusercontent.com/SAA-SDT/eac-cpf-schema/development/xml-schemas/eac-cpf/'" as="xs:string"/>
    <xsl:param name="schema-name" select="'eac' || '.' || $schema-output-version" as="xs:string"/>
    <xsl:param name="schematron-file" select="'https://raw.githubusercontent.com/SAA-SDT/eac-cpf-schema/development/xml-schemas/eac-cpf/schematron/eac.sch'" as="xs:string"/>
    
    <!-- if the cpfRelation type cannot be discerned from the input data, this value will be used as a backup. other valid options: corporateBody, person, family -->
    <xsl:param name="default-cpfRelation" select="'agent'" as="xs:string"/>


    <!-- Global Variables -->
    <xsl:variable name="changed-element-names" select="map{
        'abbreviation': 'shortCode',
        'citation': 'reference',
        'cpfRelation': 'relation',
        'eac-cpf': 'eac',
        'entityId': 'identityId',
        'functionRelation': 'relation',
        'level': 'list',
        'outline': 'list',
        'placeEntry': 'placeName',
        'nameEntryParallel': 'nameEntrySet',
        'resourceRelation': 'relation',
        'script': 'writingSystem',
        'sourceEntry': 'reference'}
        "/>
        
    <xsl:variable name="description-singular-and-plural" as="element(mapping)">
        <mapping>
            <term singular="function" plural="functions"/> 
            <term singular="languageUsed" plural="languagesUsed"/> 
            <term singular="legalStatus" plural="legalStatuses"/> 
            <term singular="localDescription" plural="localDescriptions"/> 
            <term singular="mandate" plural="mandates"/> 
            <term singular="occupation" plural="occupations"/> 
            <term singular="place" plural="places"/> 
        </mapping>
    </xsl:variable>
    
    <xsl:variable name="eac-existing-conventions" as="item()*">
        <xsl:sequence select="eac:eac-cpf/eac:control/eac:conventionDeclaration/eac:abbreviation"/>
    </xsl:variable>
    
    <xsl:variable name="eac-transliterations">
        <transliterations>
            <xsl:for-each select="distinct-values(//eac:*/@transliteration)">
                <xsl:sort data-type="text"/>
                <value id="{'cd-t-' || current-dateTime() => string() => replace(':', '') || '-' || position()}">
                    <xsl:value-of select="."/>
                </value>
            </xsl:for-each>
        </transliterations>
    </xsl:variable>
       
    <xsl:variable name="eac-new-conventions">
        <agencies>
            <xsl:for-each select="distinct-values((//eac:authorizedForm/normalize-space(), //eac:alternativeForm/normalize-space(), //eac:preferredForm/normalize-space()))">
                <xsl:sort data-type="text"/>
                <value id="{'cd-ne-' || current-dateTime() => string() => replace(':', '') || '-' || position()}">
                    <xsl:value-of select="."/>
                </value>
            </xsl:for-each>        
        </agencies>
    </xsl:variable>
    
    <xsl:variable name="newline">
        <xsl:text>&#10;</xsl:text>
    </xsl:variable>
    
    
    <!-- Primary Templates --> 
    <xsl:template match="/">
        <xsl:if test="$schema-output-version eq 'rng'">
            <xsl:processing-instruction name="xml-model">
                <xsl:text expand-text="true">href="{$schema-path}{$schema-name}" type="application/xml" schematypens="http://relaxng.org/ns/structure/1.0"</xsl:text>
            </xsl:processing-instruction>
        </xsl:if>
        <xsl:processing-instruction name="xml-model">
                <xsl:text expand-text="true">href="{$schematron-file}" type="application/xml" schematypens="http://purl.oclc.org/dsdl/schematron"</xsl:text>
            </xsl:processing-instruction>
        <xsl:apply-templates select="comment() | *:eac-cpf"/>
    </xsl:template>
    
    <xsl:template match="eac:*">
        <xsl:variable name="current-node-name" select="local-name()"/>
        <xsl:element name="{if (map:contains($changed-element-names, $current-node-name)) then map:get($changed-element-names, $current-node-name) else $current-node-name}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | node()"/>
        </xsl:element>
    </xsl:template>

    <xsl:template match="eac:eac-cpf">
        <xsl:element name="{map:get($changed-element-names, local-name())}" namespace="{$eac-xmlns}">
            <xsl:if test="$schema-output-version eq 'xsd'">
                <xsl:attribute name="schemaLocation" namespace="http://www.w3.org/2001/XMLSchema-instance">
                    <xsl:text expand-text="true">{$eac-xmlns} {$schema-path}{$schema-name}</xsl:text>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="@xml:* | node()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:objectXMLWrap">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <xsl:copy-of select="*"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:placeEntry">
        <xsl:element name="{map:get($changed-element-names, local-name())}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@xml:id, @xml:lang, @localType, @countryCode, @scriptCode, @transliteration"/>
            <xsl:apply-templates select="@accuracy, @accuarcy, @altitude, @latitude, @longitude" mode="copy-into-local-namespace"/>
            <xsl:apply-templates select="node()"/>
        </xsl:element>
        <xsl:if test="$attempt-to-convert-to-geocoordinates eq true()
            and @latitude and @longitude
            and not(parent::*/local-name() = ('function', 'legalStatus', 'localDescription', 'mandate', 'occupation'))">
            <xsl:element name="geographicCoordinates" namespace="{$eac-xmlns}">
                <xsl:attribute name="coordinateSystem" select="$default-coordinate-system"/>
                <xsl:value-of select="@latitude, @longitude, @altitude" separator=" "/>
            </xsl:element>
        </xsl:if>
    </xsl:template>
    
    <!-- consider adding a message -->
    <xsl:template match="eac:dateRange[not(eac:*)]">
        <xsl:apply-templates select="@* | node()"/>
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:call-template name="create-empty-element">
                <xsl:with-param name="element-name" select="'fromDate'"/>
            </xsl:call-template>  
        </xsl:element>
    </xsl:template>
    
    <!-- consider adding a message -->
    <xsl:template match="eac:existDates[not(eac:*)]">
        <xsl:apply-templates select="@*|node()"/>
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:call-template name="create-empty-element">
                <xsl:with-param name="element-name" select="'date'"/>
            </xsl:call-template>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="@xlink:role | @xlink:title">
        <xsl:attribute name="{concat('link', upper-case(substring(local-name(),1,1)), substring(local-name(), 2))}">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>
    
    <xsl:template match="@xlink:actuate[$retain-xlink-actuate-show-and-type eq false()] | @xlink:show [$retain-xlink-actuate-show-and-type eq false()] | @xlink:type[$retain-xlink-actuate-show-and-type eq false()]"/>
    
    <xsl:template match="@xlink:type[not(. eq 'simple')]">
        <xsl:message expand-text="true" terminate="no">Invalid xlink:type attribute detected. This attribute is being removed from EAC 2.0 regardless, but just a note in case you were using this attribute for another reason that you need to migrate in some other fashion.
        Encountered xlink:type value = {.}</xsl:message>
    </xsl:template>
    
    <xsl:template match="@xml:id" mode="element-becomes-attribute">
        <xsl:variable name="attribute-name" select="../local-name() || '-' || local-name()"/>
        <xsl:attribute name="eac1:{$attribute-name}" namespace="{$eac-xlmns-migration}">
            <xsl:value-of select="." />
        </xsl:attribute>
    </xsl:template>
    
    <xsl:template match="@xml:base | @xml:id | @xml:lang | @xlink:href">
        <xsl:variable name="lang" select="if (local-name() eq 'lang') then true() else false()"/>
        <xsl:attribute name="{if ($lang) then 'languageOfElement' else local-name()}">
            <xsl:value-of select="if ($lang and not(normalize-space())) then $default-xml-lang else ."/>
        </xsl:attribute>
    </xsl:template>
     
    <!-- change to copy in as the migration namespace, perhaps.  see the next template. --> 
    <xsl:template match="@lastDateTimeVerified | @localType" mode="standalone-comment">
        <xsl:comment>
            <xsl:value-of select="name() || '=&quot;' || . || '&quot;'"/>
        </xsl:comment>
    </xsl:template>
    
    <xsl:template match="@*" mode="copy-into-local-namespace">
        <xsl:variable name="attribute-name" select="if (local-name() eq 'accuarcy') then 'accuracy' else local-name()"/>
        <xsl:attribute name="eac1:{$attribute-name}" namespace="{$eac-xlmns-migration}" select="."/>
    </xsl:template>
    
    <xsl:template match="@*" mode="copy-into-a-comment">
        <xsl:value-of select="' ' || name() || '=&quot;' || . || '&quot;'"/>
    </xsl:template>
    
    <xsl:template match="eac:*" mode="copy-into-a-comment">
        <xsl:value-of select="$newline"/>
        <xsl:value-of select="'&lt;' || local-name()"/>
            <xsl:apply-templates select="@*" mode="#current"/>
        <xsl:value-of select="'&gt;'"/>
            <xsl:apply-templates select="eac:*|text()" mode="#current"/>
        <xsl:value-of select="'&lt;/' || local-name() || '&gt;'"/>
        <xsl:value-of select="$newline"/>
    </xsl:template>
    
    <xsl:template match="@scriptCode[parent::eac:* except parent::eac:script]">
        <xsl:attribute name="scriptOfElement">
            <xsl:copy/>
        </xsl:attribute>
    </xsl:template>
    
    <xsl:template match="@transliteration">
        <xsl:attribute name="conventionDeclarationReference">
            <xsl:value-of select="($eac-existing-conventions[normalize-space() eq current()/normalize-space()]/../@xml:id
                , $eac-existing-conventions[normalize-space() eq current()/normalize-space()]/../generate-id()
                , $eac-transliterations/transliterations/value[. eq current()]/@id)[1]"/>
        </xsl:attribute>
    </xsl:template>
    
    
      
    <!-- CONTROL SECTION -->
    
    <xsl:template match="eac:control">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@xml:*"/>
            <!-- and the elements turned attributes -->
            <xsl:apply-templates select="eac:maintenanceStatus, eac:publicationStatus"/> 
            <!-- next, the required elements -->
            <xsl:apply-templates select="eac:recordId, eac:maintenanceAgency, eac:maintenanceHistory"/>
            <!-- and the rest -->
            <xsl:apply-templates select="eac:sources, eac:otherRecordId"/> <!-- missing here is representation, but that's new to EAC 2. -->
            <xsl:apply-templates select="eac:conventionDeclaration"/>
            <xsl:call-template name="nameforms-to-convention"/>
            <xsl:call-template name="transliteration-to-convention"/>
            <xsl:apply-templates select="eac:languageDeclaration, eac:localTypeDeclaration, eac:localControl, eac:rightsDeclaration"/>
            <!-- not ideal to throw at the end, but since we have to be very strict about the order elsewhere... -->
            <xsl:apply-templates select="comment() | processing-instruction()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:maintenanceAgency">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <xsl:apply-templates select="eac:agencyCode, eac:agencyName, eac:otherAgencyCode, eac:descriptiveNote"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:maintenanceHistory[$include-migration-maintenanceEvent]">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() |processing-instruction()"/>
            <xsl:element name="maintenanceEvent" namespace="{$eac-xmlns}">
                <xsl:attribute name="maintenanceEventType" select="$default-migration-event-type"/>
                <xsl:if test="not(ancestor-or-self::eac:*[@xml:lang][1]/@xml:lang eq $default-xml-lang)">
                    <xsl:attribute name="languageOfElement" select="$default-xml-lang"/>
                </xsl:if>
                <xsl:element name="agent" namespace="{$eac-xmlns}">
                    <xsl:attribute name="agentType" select="'machine'"/>
                    <xsl:value-of select="$default-migration-agent-name"/>
                </xsl:element>
                <xsl:element name="eventDateTime" namespace="{$eac-xmlns}">
                    <xsl:attribute name="standardDateTime" select="current-dateTime()"/>
                </xsl:element>
                <xsl:element name="eventDescription" namespace="{$eac-xmlns}">
                    <xsl:value-of select="$default-migration-text"/>
                </xsl:element>
            </xsl:element>
            <xsl:apply-templates>
                <xsl:sort select="eac:eventDateTime/@standardDateTime" order="{$maintenanceEvent-sort-order}"/>
            </xsl:apply-templates>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:maintenanceEvent">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | eac:eventType"/>
            <xsl:apply-templates select="comment() | eac:agent, eac:eventDateTime, eac:eventDescription"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:agent">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* |../eac:agentType"/>
            <xsl:apply-templates select="comment() | text()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:agentType | eac:eventType | eac:maintenanceStatus | eac:publicationStatus">
        <xsl:apply-templates select="@xml:id" mode="element-becomes-attribute"/>
        <xsl:attribute name="{if (local-name() eq 'eventType') then 'maintenanceEventType' else local-name()}">
            <xsl:value-of select="."/>
        </xsl:attribute>
    </xsl:template>
    
    <xsl:template match="eac:agencyName[not(normalize-space())][not(../eac:agencyCode[normalize-space()])]">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@*"/>
            <xsl:value-of select="$default-empty-element-text"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:eventDateTime[not(@standardDateTime)][not(normalize-space())]">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@*"/>
            <xsl:value-of select="$default-empty-element-text"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:languageDeclaration">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | eac:language/@languageCode | eac:script/@scriptCode"/>         
            <xsl:apply-templates select="eac:descriptiveNote | comment() | processing-instruction()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:conventionDeclaration | eac:localTypeDeclaration | eac:rightsDeclaration">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* except @localType"/>
            <xsl:if test="not(@xml:id)">
                <xsl:attribute name="id" select="generate-id()"/>
            </xsl:if>
            <xsl:apply-templates select="eac:citation, eac:* except eac:citation | comment() | processing-instruction()"/>
        </xsl:element>
        <xsl:apply-templates select="@localType" mode="standalone-comment"/>
    </xsl:template>
    
    <xsl:template match="eac:source">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="not(eac:sourceEntry)">
                <xsl:element name="reference" namespace="{$eac-xmlns}">
                    <xsl:attribute name="id" select="generate-id(self::*)"/>
                </xsl:element>
            </xsl:if>
            <xsl:apply-templates select="eac:sourceEntry, eac:objectBinWrap, eac:descriptiveNote, eac:objectXMLWrap"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template name="transliteration-to-convention">
        <xsl:for-each select="$eac-transliterations/transliterations/value[not(normalize-space() = $eac-existing-conventions)]">
            <xsl:element name="conventionDeclaration" namespace="{$eac-xmlns}">
                <xsl:attribute name="id" select="@id"/>
                <xsl:element name="reference" namespace="{$eac-xmlns}"/>
                <xsl:element name="shortCode" namespace="{$eac-xmlns}">
                    <xsl:value-of select="."/>
                </xsl:element>
            </xsl:element>
        </xsl:for-each>
    </xsl:template>
    
    <xsl:template name="nameforms-to-convention">
        <xsl:for-each select="$eac-new-conventions/agencies/value[not(normalize-space() = $eac-existing-conventions)]">
            <xsl:element name="conventionDeclaration" namespace="{$eac-xmlns}">
                <xsl:attribute name="id" select="@id"/>
                <xsl:element name="reference" namespace="{$eac-xmlns}"/>
                <xsl:element name="shortCode" namespace="{$eac-xmlns}">
                    <xsl:value-of select="."/>
                </xsl:element>
            </xsl:element>
        </xsl:for-each>
    </xsl:template>

    
    
    <!-- cpfDescription and multipleIdentities -->
    
    <xsl:template match="eac:cpfDescription">
        <xsl:param name="current-entity-type" select="eac:identity/eac:entityType/normalize-space()"/>
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:if test="not(@xml:lang) and parent::eac:multipleIdentities[@xml:lang]">
                <xsl:apply-templates select="parent::eac:multipleIdentities/@xml:lang"/>
            </xsl:if>
            <xsl:apply-templates select="@*|node()">
                <xsl:with-param name="current-entity-type" select="$current-entity-type" tunnel="true"/>
            </xsl:apply-templates>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:multipleIdentities">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* except @xml:lang | node()"/>
        </xsl:element>
    </xsl:template>
    
    
    <!-- IDENTITY SECTION -->
    
    <xsl:template match="eac:identity">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <xsl:apply-templates select="eac:entityType, eac:nameEntry | eac:nameEntryParallel, eac:entityId, eac:descriptiveNote"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:entityType">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@*"/>
            <xsl:attribute name="value" select="normalize-space()"/>
            <xsl:apply-templates select="comment() | processing-instruction()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:nameEntryParallel">
        <xsl:element name="{map:get($changed-element-names, local-name())}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            
            <xsl:apply-templates select="eac:nameEntry"/>
            <xsl:if test="not(eac:nameEntry[2])">
                <xsl:element name="nameEntry" namespace="{$eac-xmlns}">
                    <xsl:call-template name="create-empty-element">
                        <xsl:with-param name="element-name" select="'part'"/>
                        <xsl:with-param name="default-empty-text" select="$default-empty-element-text"/>
                    </xsl:call-template>
                </xsl:element>
            </xsl:if>
            
            <xsl:apply-templates select="eac:useDates"/>
            
            <xsl:if test="eac:authorizedForm or eac:alternativeForm">
                <xsl:comment>
                      <xsl:apply-templates select="eac:authorizedForm | eac:alternativeForm" mode="copy-into-a-comment"/>
                </xsl:comment>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:nameEntry">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* except @transliteration (:we will come back to transliteration later:)"/>
            <!-- up first, since it will be convered to an attribute (when nameEntry is a child of nameEntryParallel), if present -->
            <xsl:apply-templates select="eac:preferredForm[1]" mode="element-becomes-attribute"/>           
            <xsl:call-template name="determine-nameEntry-status"/>
            <xsl:call-template name="construct-conventionDeclaration-references"/>
            <xsl:if test="@transliteration">
                <xsl:comment>
                      <xsl:apply-templates select="@transliteration" mode="copy-into-a-comment"/>
                </xsl:comment>
            </xsl:if>
            <xsl:apply-templates select="eac:* except (eac:alternativeForm, eac:authorizedForm, eac:preferredForm) | comment() | processing-instruction()"/>   
            <xsl:if test="eac:alternativeForm or eac:authorizedForm or eac:preferredForm">
                <xsl:comment>
                      <xsl:apply-templates select="eac:alternativeForm | eac:authorizedForm | eac:preferredForm" mode="copy-into-a-comment"/>
                </xsl:comment>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:part[not(normalize-space())]">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <xsl:message select="$default-empty-message" terminate="no"/>
            <xsl:value-of select="$default-empty-element-text"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template name="create-empty-element">
        <xsl:param name="element-name"/>
        <xsl:param name="default-empty-text"/>
        <xsl:element name="{$element-name}" namespace="{$eac-xmlns}">
            <xsl:message select="$default-empty-message" terminate="no"/>
            <xsl:value-of select="$default-empty-text"/>
        </xsl:element>
    </xsl:template>
           
    <xsl:template name="determine-nameEntry-status">
        <xsl:choose>
            <xsl:when test="eac:authorizedForm | ../eac:authorizedForm">
                <xsl:attribute name="status" select="'authorized'"/>
            </xsl:when>
            <xsl:when test="eac:alternativeForm | ../eac:alternativeForm">
                <xsl:attribute name="status" select="'alternative'"/>
            </xsl:when>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template name="construct-conventionDeclaration-references">
        <xsl:variable name="all-forms" as="item()*">
            <xsl:sequence select="(@transliteration, eac:authorizedForm | eac:alternativeForm, eac:preferredForm, ../eac:authorizedForm | ../eac:alternativeForm)"/>
        </xsl:variable>
        <xsl:variable name="matching-ids" as="item()*">
            <xsl:sequence select="distinct-values(for $x in $all-forms return ($eac-existing-conventions[normalize-space() eq $x/normalize-space()]/../@xml:id
                , $eac-existing-conventions[normalize-space() eq $x/normalize-space()]/../generate-id()
                , $eac-new-conventions/agencies/value[normalize-space() eq $x/normalize-space()]/@id
                , $eac-transliterations/transliterations/value[. eq $x]/@id)[1])"/>
        </xsl:variable>
        <xsl:if test="exists($matching-ids)">
            <xsl:attribute name="conventionDeclarationReference" select="$matching-ids"/>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="eac:preferredForm" mode="element-becomes-attribute">
        <xsl:attribute name="preferredForm" select="'true'"/>
    </xsl:template>
    

    
    <!-- DESCRIPTION SECTION -->
    
    <xsl:template match="eac:description">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <!-- group all of the singular/plural elements into 7 possible groups -->
            <xsl:for-each-group select="* except (eac:existDates | eac:biogHist | eac:generalContext | eac:structureOrGenealogy)"
                group-by="($description-singular-and-plural/term[@singular eq current()/local-name()]/@plural, local-name())[1]">
                <xsl:sort select="current-grouping-key()"/>
                <!-- wrap everything up into a single plural element -->
                <xsl:element name="{current-grouping-key()}" namespace="{$eac-xmlns}">
                    <!-- only include the attributes from the first plural element, if any -->
                    <xsl:apply-templates select="current-group()[local-name() eq current-grouping-key()][@*][1]/@*"/>  
                    <xsl:for-each select="current-group()">
                        <xsl:variable name="singular-name" select="($description-singular-and-plural/term[@plural eq current()/local-name()]/@singular, local-name())[1]"/>
                        <xsl:call-template name="singular-plural-dance">
                            <xsl:with-param name="singular" select="current()[local-name() eq $singular-name]"/>
                            <xsl:with-param name="plural" select="current()[local-name() eq current-grouping-key()]"/>
                            <xsl:with-param name="singular-element-name" select="$singular-name" as="item()"/>
                        </xsl:call-template>
                    </xsl:for-each>
                    <xsl:if test="current-group()[local-name() eq current-grouping-key()]/*[local-name() = ('citation', 'p')]">
                        <xsl:element name="descriptiveNote" namespace="{$eac-xmlns}">
                            <xsl:apply-templates select="current-group()[local-name() eq current-grouping-key()]/*[local-name() = ('citation', 'p')]" mode="element-to-paragraph"/>
                        </xsl:element>
                    </xsl:if>
                </xsl:element>
            </xsl:for-each-group>
            <xsl:apply-templates select="eac:existDates | eac:biogHist | eac:generalContext | eac:structureOrGenealogy"/>
        </xsl:element>
    </xsl:template>
    
    
    <xsl:template name="singular-plural-dance">
        <xsl:param name="singular"/>
        <xsl:param name="plural"/>
        <xsl:param name="singular-element-name"/>
        <xsl:apply-templates select="$plural[1]/eac:*[local-name() eq $singular-element-name] | $plural[position() gt 1] | $singular"/>
        <xsl:if test="$plural/*[local-name() = ('list', 'outline')]">
            <xsl:comment>
                <xsl:apply-templates select="$plural/*[local-name() = ('list', 'outline')]" mode="copy-into-a-comment"/>               
             </xsl:comment>
        </xsl:if>
    </xsl:template>
    
    
    <xsl:template match="eac:*[local-name() = $description-singular-and-plural/term/@singular]" priority="2">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | eac:*/@vocabularySource | comment() | processing-instruction()"/>
            <xsl:choose>
                <xsl:when test="self::eac:place">
                    <xsl:apply-templates select="eac:placeEntry, eac:placeRole, eac:address, eac:date, eac:dateRange, eac:dateSet"/>
                    <xsl:if test="not(*)">
                        <xsl:element name="placeName" namespace="{$eac-xmlns}">
                            <xsl:attribute name="id" select="generate-id()"/>
                        </xsl:element>
                    </xsl:if>
                </xsl:when>
                <xsl:when test="self::eac:languageUsed">
                    <xsl:apply-templates select="eac:language, eac:script"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="eac:term, eac:date, eac:dateRange, eac:dateSet, eac:placeEntry"/>
                    <xsl:if test="not(eac:term)">
                        <xsl:element name="term" namespace="{$eac-xmlns}">
                            <xsl:attribute name="id" select="generate-id()"/>
                        </xsl:element>
                    </xsl:if>
                </xsl:otherwise>
            </xsl:choose>
            <xsl:if test="eac:citation and not(eac:descriptiveNote)">
                <xsl:apply-templates select="eac:citation" mode="descriptiveNote"/>
            </xsl:if>
            <xsl:apply-templates select="eac:descriptiveNote"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:*[local-name() = $description-singular-and-plural/term/@plural]" priority="2">
        <xsl:apply-templates select="comment() | processing-instruction()"/>
        <xsl:if test="@*">
            <xsl:comment>
                <xsl:apply-templates select="@*" mode="copy-into-a-comment"/>
            </xsl:comment>
        </xsl:if>
        <xsl:if test="@* or *">
            <xsl:comment>note that the following elements were grouped previously, when the plural elements could repeat in EAC 1.x</xsl:comment>
                <xsl:apply-templates select="eac:* except (eac:citation, eac:list, eac:outline, eac:p) | comment() | processing-instruction()"/>
            <xsl:comment>note that the preceding elements were grouped previously, when the plural elements could repeat in EAC 1.x</xsl:comment> 
        </xsl:if>
    </xsl:template>

    
    <!-- an extra template, just due to placeRole/@lastDateTimeVerified no longer being an option. Alternatively, we could add this as a new attribute in the migration namespace. -->
    <xsl:template match="eac:placeRole">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* except @lastDateTimeVerified | node()"/>
        </xsl:element>
        <xsl:apply-templates select="@lastDateTimeVerified" mode="standalone-comment"/>
    </xsl:template>
    
    <xsl:template match="eac:chronItem">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <xsl:apply-templates select="eac:* except eac:placeEntry"/>
            <xsl:apply-templates select="eac:placeEntry" mode="chronItem"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:descriptiveNote">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | node()"/>
            <xsl:if test="ancestor::eac:description">
                <xsl:apply-templates select="../eac:citation" mode="element-to-paragraph"/>
            </xsl:if>
            <xsl:if test="../eac:list">
                <xsl:comment>
                    <xsl:apply-templates select="../eac:list" mode="copy-into-a-comment"/>
                </xsl:comment>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:term">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <!-- term/@vocabularlySource will be handled on the parent element -->
            <xsl:apply-templates select="@xml:id | @xml:lang | @scriptCode | @transliteration"/>
            <xsl:apply-templates select="node()"/>
        </xsl:element>
        <xsl:apply-templates select="@lastDateTimeVerified" mode="standalone-comment"/>
    </xsl:template>
    
    <xsl:template match="eac:citation" mode="descriptiveNote">
        <xsl:element name="descriptiveNote" namespace="{$eac-xmlns}">
            <xsl:attribute name="eac1:citation" namespace="{$eac-xlmns-migration}" select="'migrated-' || local-name()"/>
            <xsl:apply-templates select="." mode="element-to-paragraph"/>
        </xsl:element>
        <xsl:apply-templates select="@lastDateTimeVerified" mode="standalone-comment"/>
    </xsl:template>
    
    <!-- also need to convert any floating citation elements into paragraphs in the following places. -->
    <xsl:template match="eac:biogHist/eac:citation | eac:generalContext/eac:citation | eac:structureOrGenealogy/eac:citation">
        <xsl:apply-templates select="." mode="element-to-paragraph"/>
    </xsl:template>
    
    <xsl:template match="eac:*" mode="element-to-paragraph">
        <xsl:element name="p" namespace="{$eac-xmlns}">
            <xsl:attribute name="eac1:migrationType" namespace="{$eac-xlmns-migration}" select="'migrated-' || local-name()"/>
            <xsl:choose>
                <xsl:when test="self::eac:citation">
                    <xsl:element name="{map:get($changed-element-names, local-name())}" namespace="{$eac-xmlns}">
                        <xsl:apply-templates select="@* except @lastDateTimeVerified | node()"/>
                    </xsl:element>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="@* except @lastDateTimeVerified | node()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:element>
        <xsl:apply-templates select="@lastDateTimeVerified" mode="standalone-comment"/>
    </xsl:template>
   


    
    <!-- RELATIONS SECTION -->
    
    <xsl:template match="eac:relations[not(*)]">
        <xsl:comment expand-text="true">The following empty element was encountered and has been removed: {name()}. If that element had attributes present in the source file, then those will appear in following comments.</xsl:comment>
        <xsl:apply-templates select="@*" mode="standalone-comment"/>
        <xsl:apply-templates select="comment() | processing-instruction()"/>
    </xsl:template>
        
    
    <xsl:template match="eac:cpfRelation | eac:functionRelation | eac:resourceRelation">
        <xsl:param name="current-entity-type" tunnel="true"/>
        <xsl:variable name="current-type" select="substring-before(local-name(), 'Relation')"/>
        <xsl:element name="{map:get($changed-element-names, local-name())}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@xml:lang | @xml:id | @xlink:actuate | @xlink:show | @xlink:type"/>
            <xsl:apply-templates select="comment() | processing-instruction()"/>

            <xsl:apply-templates select="@lastDateTimeVerified" mode="standalone-comment"/>
            
            <xsl:element name="targetEntity" namespace="{$eac-xmlns}">
                <!-- add xlink:role here as a backup? -->
                <xsl:attribute name="targetType" select="if ((@cpfRelationType eq 'identity') and ($current-type eq 'cpf')) then $current-entity-type else if ($current-type eq 'cpf') then $default-cpf-type else $current-type"/>
                <xsl:apply-templates select="@xlink:href | @xlink:title | @xlink:role" mode="relations"/>
                <xsl:apply-templates select="eac:relationEntry[normalize-space()]"/>
                
                <xsl:if test="not(eac:relationEntry[normalize-space()])">
                    <xsl:element name="part" namespace="{$eac-xmlns}">
                        <xsl:message select="$default-empty-element-text" terminate="false"/>
                        <xsl:value-of select="$default-empty-element-text"/>
                    </xsl:element>
                </xsl:if>
            </xsl:element>
            
            <xsl:apply-templates select="eac:date | eac:dateSet | eac:dateRange"/>
            
            <xsl:apply-templates select="@cpfRelationType, @functionRelationType, @resourceRelationType"/>
            
            <xsl:apply-templates select="@xlink:arcrole" mode="relations"/>
            
            <xsl:apply-templates select="eac:placeEntry" mode="relations"/> <!-- will need to promote to place -->
            <xsl:apply-templates select="eac:descriptiveNote, eac:objectXMLWrap, eac:objectBinWrap"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="eac:placeEntry" mode="relations chronItem">
        <xsl:element name="place" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="."/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="@xlink:arcrole" mode="relations">
        <xsl:element name="targetRole" namespace="{$eac-xmlns}">
            <xsl:attribute name="valueURI" select="normalize-space()"/>
        </xsl:element>
    </xsl:template>
    
    <!-- what else could we map this to? not sure, so keeping in the xlink namespace -->
    <xsl:template match="@xlink:title | @xlink:role" mode="relations">
        <xsl:copy>
            <xsl:value-of select="."/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@xlink:href" mode="relations">
        <xsl:attribute name="valueURI" select="normalize-space()"/>
    </xsl:template>
    
    <xsl:template match="eac:relationEntry">
        <xsl:apply-templates select="comment() | processing-instruction()"/>
        <!-- might be better to repeat the relation for multiple relationEntry elements, but for now i am parking these in part elements -->
        <xsl:element name="part" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | text()"/>
        </xsl:element>
    </xsl:template>
    
    <xsl:template match="@cpfRelationType | @functionRelationType | @resourceRelationType">
        <xsl:element name="relationType" namespace="{$eac-xmlns}">
            <xsl:value-of select="normalize-space()"/>
        </xsl:element>
    </xsl:template>
    
    <!-- ALTERNATIVE SET SECTION -->
    
    <xsl:template match="eac:setComponent">
        <xsl:element name="{local-name()}" namespace="{$eac-xmlns}">
            <xsl:apply-templates select="@* | comment() | processing-instruction()"/>
            <xsl:apply-templates select="eac:componentEntry, eac:descriptiveNote, eac:objectXMLWrap, eac:objectBinWrap"/>
        </xsl:element>
    </xsl:template>

    
    <!-- banished elements -->
    <xsl:template match="eac:objectBinWrap">
        <xsl:message expand-text="true" terminate="no">This element, {local-name()}, has been removed from EAC-CPF 2.0, and so, it will be replaced with a comment in the output file.  Please refer to your original EAC file to determine whether this data should be migrated another way, possibly using a resource relation.</xsl:message>
        <xsl:comment expand-text="true">This element, {local-name()}, has been removed from EAC-CPF 2.0, and so, it has been removed from this corresponding output file.  Please refer to your original EAC file to determine whether this data should be migrated another way, possibly using a resource relation.</xsl:comment>
    </xsl:template>
    
</xsl:stylesheet>
