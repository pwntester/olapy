"""Managing all
`DISCOVER <https://technet.microsoft.com/fr-fr/library/ms186653(v=sql.110).aspx>`_
requests and responses."""

import os
import uuid
from urllib.parse import urlparse
# import xmlwitch

from libcythonplus.list cimport cyplist
from olapy.stdlib.string cimport Str
from olapy.stdlib.format cimport format
from olapy.cypxml cimport cypXML, Elem, to_str

try:
    from sqlalchemy import create_engine
except ImportError:
    pass

from olapy.core.parse import split_tuple
from olapy.core.services.structures cimport STuple, RowTuples, SchemaResponse
from olapy.core.services.xmla_discover_literals_response_rows_s cimport discover_literals_response_rows_l
from olapy.core.services.xmla_discover_schema_rowsets_response_rows_s cimport discover_schema_rowsets_response_rows_l
from olapy.core.services.xmla_discover_schema_rowsets_response_items cimport (
    MDSCHEMA_HIERARCHIES_sr, MDSCHEMA_MEASURES_sr, DBSCHEMA_TABLES_sr,
    DISCOVER_DATASOURCES_sr, DISCOVER_INSTANCES_sr, DISCOVER_KEYWORDS_sr)
from olapy.core.services.schema_response cimport discover_schema_rowsets_response_str

from olapy.core.services.xmla_discover_xsds_s cimport (
    dbschema_catalogs_xsd_s,
    dbschema_tables_xsd_s,
    discover_datasources_xsd_s,
    discover_enumerators_xsd_s,
    discover_keywords_xsd_s,
    discover_literals_xsd_s,
    discover_preperties_xsd_s,
    discover_schema_rowsets_xsd_s,
    mdschema_cubes_xsd_s,
    mdschema_dimensions_xsd_s,
    mdschema_functions_xsd_s,
    mdschema_hierarchies_xsd_s,
    mdschema_kpis_xsd_s,
    mdschema_levels_xsd_s,
    mdschema_measures_xsd_s,
    mdschema_measuresgroups_dimensions_xsd_s,
    mdschema_measuresgroups_xsd_s,
    mdschema_members_xsd_s,
    mdschema_properties_properties_xsd_s,
    mdschema_sets_xsd_s,
)
from olapy.core.services.xmla_discover_properties_xml cimport properties_xml
from olapy.core.services.utils cimport (
    bracket,
    dot_bracket,
    pylist_to_cyplist,
    cypstr_copy_slice_to
)
from olapy.core.services.xmla_discover_fill_xml cimport (
    fill_dimension,
    fill_dimension_measures,
    fill_cube,
    fill_mds_measures,
    fill_mds_hier_table,
    fill_mds_hier_name,
    fill_mds_levels_table,
    fill_mds_levels_measure,
    fill_mds_measuregroups,
    fill_mds_measuregroup_dimensions,
    fill_mds_properties,
    fill_mds_members_a,
    fill_mds_members_b,
)

# noinspection PyPep8Naming


cdef Elem root_element_with_xsd(cypXML xml, Str xsd) nogil:
    cdef Elem root

    ret = xml.stag("return")
    root = ret.stag("root")
    root.sattr("xmlns", "urn:schemas-microsoft-com:xml-analysis:rowset")
    root.sattr("xmlns:xsd", "http://www.w3.org/2001/XMLSchema")
    root.sattr("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
    root.append(xsd)
    return root


class XmlaDiscoverReqHandler:
    """XmlaDiscoverReqHandler handles information, such as the list of
    available databases or details about a specific object (cube, dimensions,
    hierarchies...), from an instance of MdxEngine.

    The data retrieved with the Discover method depends on the values of
    the parameters passed to it.
    """
    def __init__(self, mdx_engine):
        # type: (MdxEngine) -> None
        """

        :param mdx_engine: mdx_engine engine instance

        """
        self.executor = mdx_engine
        if self.executor.sqla_engine:
            # save sqla uri so we can change it with new database
            self.sql_alchemy_uri = str(self.executor.sqla_engine.url)
        self.cubes = self.executor.get_cubes_names()
        self.selected_cube = None
        self.session_id = uuid.uuid1()

    def _change_db_uri(self, old_sqla_uri, new_db):
        # scheme, netloc, path, params, query, fragment = urlparse(old_sqla_uri)
        # urlunparse((scheme, netloc, new_db, params, query, fragment))
        # urlunparse -> bad result with sqlite://
        parse_uri = urlparse(old_sqla_uri)
        return parse_uri.scheme + "://" + parse_uri.netloc + "/" + new_db

    def change_cube(self, new_cube):
        """If you change the cube in any request, we have to instantiate the
        MdxEngine with the new cube.

        :param new_cube: cube name
        :return: new instance of MdxEngine with new star_schema_DataFrame and other variables
        """
        if new_cube == self.selected_cube:
            return

        if (
            self.executor.cube_config
            and new_cube == self.executor.cube_config["name"]
        ):
            facts = self.executor.cube_config["facts"]["table_name"]
        else:
            facts = "Facts"

        self.selected_cube = new_cube

        if "db" in self.executor.source_type:
            new_sql_alchemy_uri = self._change_db_uri(
                self.sql_alchemy_uri, new_cube
            )
            self.executor.sqla_engine = create_engine(new_sql_alchemy_uri)
        if self.executor.cube != new_cube:
            self.executor.load_cube(new_cube, fact_table_name=facts)

    @staticmethod
    def discover_datasources_response():
        """List the data sources available on the server.

        :return:
        """
        # Rem: This is hardcoded response
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:EX": "urn:schemas-microsoft-com:xml-analysis:exception",
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_datasources_xsd)
        #         with xml.row:
        #             xml.DataSourceName("sales")
        #             xml.DataSourceDescription("sales Sample Data")
        #             xml.URL("http://127.0.0.1:8000/xmla")
        #             xml.DataSourceInfo("-")
        #             xml.ProviderName("olapy")
        #             xml.ProviderType("MDP")
        #             xml.AuthenticationMode("Unauthenticated")
        ret = xml.stag("return")
        root = ret.stag("root")
        root.sattr("xmlns", "urn:schemas-microsoft-com:xml-analysis:rowset")
        root.sattr("xmlns:EX", "urn:schemas-microsoft-com:xml-analysis:exception")
        root.sattr("xmlns:xsd", "http://www.w3.org/2001/XMLSchema")
        root.sattr("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
        root.append(discover_datasources_xsd_s)
        row = root.stag("row")
        row.stag("DataSourceName").stext("sales")
        row.stag("DataSourceDescription").stext("sales Sample Data")
        row.stag("URL").stext("http://127.0.0.1:8000/xmla")
        row.stag("DataSourceInfo").stext("-")
        row.stag("ProviderName").stext("olapy")
        row.stag("ProviderType").stext("MDP")
        row.stag("AuthenticationMode").stext("Unauthenticated")

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    # @staticmethod
    # def _get_properties(
    #     xsd,
    #     PropertyName,
    #     PropertyDescription,
    #     PropertyType,
    #     PropertyAccessType,
    #     IsRequired,
    #     Value,
    # ):
    #     cdef cypXML xml
    #     cdef Str result
    #
    #     # xml = xmlwitch.Builder()
    #     xml = cypXML()
    #     xml.set_max_depth(0)
    #     # with xml["return"]:
    #     #     with xml.root(
    #     #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
    #     #         **{
    #     #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
    #     #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
    #     #         },
    #     #     ):
    #     #         xml.write(xsd)
    #     #         if PropertyName:
    #     #
    #     #             with xml.row:
    #     #                 xml.PropertyName(PropertyName)
    #     #                 xml.PropertyDescription(PropertyDescription)
    #     #                 xml.PropertyType(PropertyType)
    #     #                 xml.PropertyAccessType(PropertyAccessType)
    #     #                 xml.IsRequired(IsRequired)
    #     #                 xml.Value(Value)
    #     #
    #     #         else:
    #     #             properties_names_n_description = [
    #     #                 "ServerName",
    #     #                 "ProviderVersion",
    #     #                 "MdpropMdxSubqueries",
    #     #                 "MdpropMdxDrillFunctions",
    #     #                 "MdpropMdxNamedSets",
    #     #             ]
    #     #             properties_types = ["string", "string", "int", "int", "int"]
    #     #             values = [
    #     #                 os.getenv("USERNAME", "default"),
    #     #                 "0.0.3  25-Nov-2016 07:20:28 GMT",
    #     #                 "15",
    #     #                 "3",
    #     #                 "15",
    #     #             ]
    #     #
    #     #             for idx, prop_desc in enumerate(properties_names_n_description):
    #     #                 with xml.row:
    #     #                     xml.PropertyName(prop_desc)
    #     #                     xml.PropertyDescription(prop_desc)
    #     #                     xml.PropertyType(properties_types[idx])
    #     #                     xml.PropertyAccessType("Read")
    #     #                     xml.IsRequired("false")
    #     #                     xml.Value(values[idx])
    #     ret = xml.stag("return")
    #     root = ret.stag("root")
    #     root.sattr("xmlns", "urn:schemas-microsoft-com:xml-analysis:rowset")
    #     root.sattr("xmlns:xsd", "http://www.w3.org/2001/XMLSchema")
    #     root.sattr("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
    #     root.append(to_str(xsd))
    #     row = root.stag("row")
    #     if PropertyName:
    #         row.stag("PropertyName").text(to_str(PropertyName))
    #         row.stag("PropertyDescription").text(to_str(PropertyDescription))
    #         row.stag("PropertyType").text(to_str(PropertyType))
    #         row.stag("PropertyAccessType").text(to_str(PropertyAccessType))
    #         row.stag("IsRequired").text(to_str(IsRequired))
    #         row.stag("Value").text(to_str(str(Value)))
    #     else:
    #         properties_names_n_description = [
    #             "ServerName",
    #             "ProviderVersion",
    #             "MdpropMdxSubqueries",
    #             "MdpropMdxDrillFunctions",
    #             "MdpropMdxNamedSets",
    #         ]
    #         properties_types = ["string", "string", "int", "int", "int"]
    #         values = [
    #             os.getenv("USERNAME", "default"),
    #             "0.0.3  25-Nov-2016 07:20:28 GMT",
    #             "15",
    #             "3",
    #             "15",
    #         ]
    #         for idx, prop_desc in enumerate(properties_names_n_description):
    #             row.stag("PropertyName").text(to_str(prop_desc))
    #             row.stag("PropertyDescription").text(to_str(prop_desc))
    #             row.stag("PropertyType").text(to_str(properties_types[idx]))
    #             row.stag("PropertyAccessType").stext("Read")
    #             row.stag("IsRequired").stext("false")
    #             row.stag("Value").text(to_str(values[idx]))
    #
    #     # return str(xml)
    #     result = xml.dump()
    #     return result.bytes().decode("utf8")


    def _get_properties_by_restrictions(self, request):
        if request.Restrictions.RestrictionList.PropertyName == "Catalog":
            if request.Properties.PropertyList.Catalog is not None:
                self.change_cube(
                    request.Properties.PropertyList.Catalog.replace("[", "").replace(
                        "]", ""
                    )
                )
                value = self.selected_cube
            else:
                value = self.cubes[0]

            return properties_xml(
                discover_preperties_xsd_s,
                Str("Catalog"),
                Str("Catalog"),
                Str("string"),
                Str("ReadWrite"),
                Str("false"),
                Str(value.encode("utf8", "replace")),
            ).bytes().decode("utf8")

        elif request.Restrictions.RestrictionList.PropertyName == "ServerName":
            return properties_xml(
                discover_preperties_xsd_s,
                Str("ServerName"),
                Str("ServerName"),
                Str("string"),
                Str("Read"),
                Str("false"),
                Str("Mouadh"),
            ).bytes().decode("utf8")

        elif request.Restrictions.RestrictionList.PropertyName == "ProviderVersion":
            return properties_xml(
                discover_preperties_xsd_s,
                Str("ProviderVersion"),
                Str("ProviderVersion"),
                Str("string"),
                Str("Read"),
                Str("false"),
                Str("0.02  08-Mar-2016 08:41:28 GMT"),
            ).bytes().decode("utf8")

        elif request.Restrictions.RestrictionList.PropertyName == "MdpropMdxSubqueries":
            if request.Properties.PropertyList.Catalog is not None:
                self.change_cube(request.Properties.PropertyList.Catalog)

            return properties_xml(
                discover_preperties_xsd_s,
                Str("MdpropMdxSubqueries"),
                Str("MdpropMdxSubqueries"),
                Str("int"),
                Str("Read"),
                Str("false"),
                Str("15"),
            ).bytes().decode("utf8")

        elif (
            request.Restrictions.RestrictionList.PropertyName
            == "MdpropMdxDrillFunctions"
        ):
            if request.Properties.PropertyList.Catalog is not None:
                self.change_cube(request.Properties.PropertyList.Catalog)

            return properties_xml(
                discover_preperties_xsd_s,
                Str("MdpropMdxDrillFunctions"),
                Str("MdpropMdxDrillFunctions"),
                Str("int"),
                Str("Read"),
                Str("false"),
                Str("3"),
            ).bytes().decode("utf8")

        elif request.Restrictions.RestrictionList.PropertyName == "MdpropMdxNamedSets":
            return properties_xml(
                discover_preperties_xsd_s,
                Str("MdpropMdxNamedSets"),
                Str("MdpropMdxNamedSets"),
                Str("int"),
                Str("Read"),
                Str("false"),
                Str("15"),
            ).bytes().decode("utf8")

        return properties_xml(
            discover_preperties_xsd_s, Str(), Str(), Str(), Str(), Str(), Str()
        ).bytes().decode("utf8")

    def discover_properties_response(self, request):
        if request.Restrictions.RestrictionList:
            return self._get_properties_by_restrictions(request)
        return properties_xml(
            discover_preperties_xsd_s, Str(), Str(), Str(), Str(), Str(), Str()
        ).bytes().decode("utf8")

    def discover_schema_rowsets_response(self, request):
        """Generate the names, restrictions, description, and other information
        for all enumeration values and any additional provider-specific
        enumeration values supported by OlaPy.

        :param request:
        :return: xmla response as string
        """
        cdef Str result
        cdef cyplist[SchemaResponse] ext

        ext = cyplist[SchemaResponse]()

        restriction_list = request.Restrictions.RestrictionList
        if restriction_list:
            if (
                restriction_list.SchemaName == "MDSCHEMA_HIERARCHIES"
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                ext.append(MDSCHEMA_HIERARCHIES_sr)
                result = discover_schema_rowsets_response_str(ext)
                return result.bytes().decode("utf8")

            if (
                restriction_list.SchemaName == "MDSCHEMA_MEASURES"
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                ext.append(MDSCHEMA_MEASURES_sr)
                result = discover_schema_rowsets_response_str(ext)
                return result.bytes().decode("utf8")

        ext.append(DBSCHEMA_TABLES_sr)
        ext.append(DISCOVER_DATASOURCES_sr)
        ext.append(DISCOVER_INSTANCES_sr)
        ext.append(DISCOVER_KEYWORDS_sr)
        for sr in discover_schema_rowsets_response_rows_l:
            ext.append(sr)
        result = discover_schema_rowsets_response_str(ext)
        return result.bytes().decode("utf8")

    @staticmethod
    def discover_literals_response(request):
        """Generate information on literals supported by the OlaPy, including
        data types and values.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result
        cdef RowTuples resp_row
        cdef STuple kv

        if (
            request.Properties.PropertyList.Content == "SchemaData"
            or request.Properties.PropertyList.Format == "Tabular"
        ):

            # rows = discover_literals_response_rows

            # xml = xmlwitch.Builder()
            xml = cypXML()
            xml.set_max_depth(1)
            # with xml["return"]:
            #     with xml.root(
            #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
            #         **{
            #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
            #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
            #         },
            #     ):
            #         xml.write(discover_literals_xsd)
            #         for resp_row in rows:
            #             with xml.row:
            #                 for att_name, value in resp_row.items():
            #                     xml[att_name](value)
            root = root_element_with_xsd(xml, discover_literals_xsd_s)
            for resp_row in discover_literals_response_rows_l:
                row = root.stag("row")
                for kv in resp_row.row:
                    row.tag(<Str>kv.key).text(<Str>kv.value)

            # return str(xml)
            result = xml.dump()
            return result.bytes().decode("utf8")

    def mdschema_sets_response(self, request):
        """Describes any sets that are currently defined in a database,
        including session-scoped sets.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_sets_xsd)
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        root = root_element_with_xsd(xml, mdschema_sets_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_kpis_response(self, request):
        """Describes the key performance indicators (KPIs) within a database.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_kpis_xsd)
        #
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        root = root_element_with_xsd(xml, mdschema_kpis_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def dbschema_catalogs_response(self, request):
        """Catalogs available for a server instance.

        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(dbschema_catalogs_xsd)
        #         for catalogue in self.cubes:
        #             with xml.row:
        #                 xml.CATALOG_NAME(catalogue)
        root = root_element_with_xsd(xml, dbschema_catalogs_xsd_s)
        for catalogue in self.cubes:
            row = root.stag("row")
            row.stag("CATALOG_NAME").text(to_str(catalogue))

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_cubes_response(self, request):
        """Describes the structure of cubes.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_cubes_xsd)
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 or request.Properties.PropertyList.Catalog is not None
        #             ):
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.CUBE_TYPE("CUBE")
        #                     xml.LAST_SCHEMA_UPDATE("2016-07-22T10:41:38")
        #                     xml.LAST_DATA_UPDATE("2016-07-22T10:41:38")
        #                     xml.DESCRIPTION("MDX " + self.selected_cube + " results")
        #                     xml.IS_DRILLTHROUGH_ENABLED("true")
        #                     xml.IS_LINKABLE("false")
        #                     xml.IS_WRITE_ENABLED("false")
        #                     xml.IS_SQL_ENABLED("false")
        #                     xml.CUBE_CAPTION(self.selected_cube)
        #                     xml.CUBE_SOURCE("1")
        root = root_element_with_xsd(xml, mdschema_cubes_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                or request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)

                row = root.stag("row")
                fill_cube(row, Str(self.selected_cube.encode("utf8", "replace")))

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def dbschema_tables_response(self, request):
        """Returns dimensions, measure groups, or schema rowsets exposed as
        tables.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        if request.Properties.PropertyList.Catalog is None:
            return

        self.change_cube(request.Properties.PropertyList.Catalog)

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(dbschema_tables_xsd)
        root = root_element_with_xsd(xml, dbschema_tables_xsd_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_measures_response(self, request):
        """Returns information about the available measures.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str cube_s
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)

        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_measures_xsd)
        #
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #                 for mes in self.executor.measures:
        #                     with xml.row:
        #                         xml.CATALOG_NAME(self.selected_cube)
        #                         xml.CUBE_NAME(self.selected_cube)
        #                         xml.MEASURE_NAME(mes)
        #                         xml.MEASURE_UNIQUE_NAME("[Measures].[" + mes + "]")
        #                         xml.MEASURE_CAPTION(mes)
        #                         xml.MEASURE_AGGREGATOR("1")
        #                         xml.DATA_TYPE("5")
        #                         xml.NUMERIC_PRECISION("16")
        #                         xml.NUMERIC_SCALE("-1")
        #                         xml.MEASURE_IS_VISIBLE("true")
        #                         xml.MEASURE_NAME_SQL_COLUMN_NAME(mes)
        #                         xml.MEASURE_UNQUALIFIED_CAPTION(mes)
        #                         xml.MEASUREGROUP_NAME("default")
        root = root_element_with_xsd(xml, mdschema_measures_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                cube_s = Str(self.selected_cube.encode("utf8", "replace"))
                for measure in self.executor.measures:
                    row = root.stag("row")
                    fill_mds_measures(
                            row,
                            cube_s,
                            Str(measure.encode("utf8", "replace"))
                        )
        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_dimensions_response(self, request):
        """Returns information about the dimensions in a given cube. Each
        dimension has one row.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result
        cdef Str catalog_name
        cdef Str tables_s
        cdef int ordinal
        cdef Str dimension_type_s
        cdef Str dimension_cardinal_s

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(1)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_dimensions_xsd)
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Restrictions.RestrictionList.CATALOG_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #                 ordinal = 1
        #                 for tables in self.executor.get_all_tables_names(
        #                     ignore_fact=True
        #                 ):
        #                     with xml.row:
        #                         xml.CATALOG_NAME(self.selected_cube)
        #                         xml.CUBE_NAME(self.selected_cube)
        #                         xml.DIMENSION_NAME(tables)
        #                         xml.DIMENSION_UNIQUE_NAME("[" + tables + "]")
        #                         xml.DIMENSION_CAPTION(tables)
        #                         xml.DIMENSION_ORDINAL(str(ordinal))
        #                         xml.DIMENSION_TYPE("3")
        #                         xml.DIMENSION_CARDINALITY("23")
        #                         xml.DEFAULT_HIERARCHY(
        #                             "[" + tables + "].[" + tables + "]"
        #                         )
        #                         xml.IS_VIRTUAL("false")
        #                         xml.IS_READWRITE("false")
        #                         xml.DIMENSION_UNIQUE_SETTINGS("1")
        #                         xml.DIMENSION_IS_VISIBLE("true")
        #                     ordinal += 1
        #
        #                 # for measure
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.DIMENSION_NAME("Measures")
        #                     xml.DIMENSION_UNIQUE_NAME("[Measures]")
        #                     xml.DIMENSION_CAPTION("Measures")
        #                     xml.DIMENSION_ORDINAL(str(ordinal))
        #                     xml.DIMENSION_TYPE("2")
        #                     xml.DIMENSION_CARDINALITY("0")
        #                     xml.DEFAULT_HIERARCHY("[Measures]")
        #                     xml.IS_VIRTUAL("false")
        #                     xml.IS_READWRITE("false")
        #                     xml.DIMENSION_UNIQUE_SETTINGS("1")
        #                     xml.DIMENSION_IS_VISIBLE("true")
        root = root_element_with_xsd(xml, mdschema_dimensions_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME
                    == self.selected_cube
                and request.Restrictions.RestrictionList.CATALOG_NAME
                    == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                ordinal = 0
                catalog_name = Str(self.selected_cube.encode("utf8", "replace"))
                dimension_type_s = Str("3")
                dimension_cardinal_s = Str("23")
                for tables in self.executor.get_all_tables_names(ignore_fact=True):
                    ordinal += 1
                    tables_s = Str(tables.encode("utf8", "replace"))
                    row = root.stag("row")
                    fill_dimension(
                        row,
                        catalog_name,
                        tables_s,
                        ordinal,
                        dimension_type_s,
                        dimension_cardinal_s
                    )
                # for measure
                ordinal += 1
                row = root.stag("row")
                fill_dimension_measures(row, catalog_name, ordinal)
        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_hierarchies_response(self, request):
        """Describes each hierarchy within a particular dimension.

        :param request:
        :return:
        """
        # Enumeration of hierarchies in all dimensions
        cdef cypXML xml
        cdef Str result, column_attribut, table_s, cube_s, default_s

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(1)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_hierarchies_xsd)
        #
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #                 # if (
        #                 #     request.Restrictions.RestrictionList.HIERARCHY_VISIBILITY == 3
        #                 #     or request.Restrictions.RestrictionList.CATALOG_NAME == self.selected_cube
        #                 # ):
        #                 for table_name, df in self.executor.tables_loaded.items():
        #                     if table_name == self.executor.facts:
        #                         continue
        #
        #                     column_attribut = df.iloc[0][0]
        #
        #                     with xml.row:
        #                         xml.CATALOG_NAME(self.selected_cube)
        #                         xml.CUBE_NAME(self.selected_cube)
        #                         xml.DIMENSION_UNIQUE_NAME("[" + table_name + "]")
        #                         xml.HIERARCHY_NAME(table_name)
        #                         xml.HIERARCHY_UNIQUE_NAME(
        #                             "[{0}].[{0}]".format(table_name)
        #                         )
        #                         xml.HIERARCHY_CAPTION(table_name)
        #                         xml.DIMENSION_TYPE("3")
        #                         xml.HIERARCHY_CARDINALITY("6")
        #                         # xml.DEFAULT_MEMBER(
        #                         #     "[{0}].[{0}].[{1}]".format(
        #                         #         table_name, column_attribut
        #                         #     )
        #                         # )
        #
        #                         # todo recheck
        #                         if (
        #                             request.Properties.PropertyList.Format
        #                             and request.Properties.PropertyList.Format.upper()
        #                             == "TABULAR"
        #                         ):
        #                             # Format found in onlyoffice and not in excel
        #                             # ALL_MEMBER causes prob with excel
        #                             xml.ALL_MEMBER(
        #                                 "[{0}].[{0}].[{1}]".format(
        #                                     table_name, column_attribut
        #                                 )
        #                             )
        #                         xml.STRUCTURE("0")
        #                         xml.IS_VIRTUAL("false")
        #                         xml.IS_READWRITE("false")
        #                         xml.DIMENSION_UNIQUE_SETTINGS("1")
        #                         xml.DIMENSION_IS_VISIBLE("true")
        #                         xml.HIERARCHY_ORDINAL("1")
        #                         xml.DIMENSION_IS_SHARED("true")
        #                         xml.HIERARCHY_IS_VISIBLE("true")
        #                         xml.HIERARCHY_ORIGIN("1")
        #                         xml.INSTANCE_SELECTION("0")
        #
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.DIMENSION_UNIQUE_NAME("[Measures]")
        #                     xml.HIERARCHY_NAME("Measures")
        #                     xml.HIERARCHY_UNIQUE_NAME("[Measures]")
        #                     xml.HIERARCHY_CAPTION("Measures")
        #                     xml.DIMENSION_TYPE("2")
        #                     xml.HIERARCHY_CARDINALITY("0")
        #                     xml.DEFAULT_MEMBER(
        #                         f"[Measures].[{self.executor.measures[0]}]"
        #                     )
        #                     xml.STRUCTURE("0")
        #                     xml.IS_VIRTUAL("false")
        #                     xml.IS_READWRITE("false")
        #                     xml.DIMENSION_UNIQUE_SETTINGS("1")
        #                     xml.DIMENSION_IS_VISIBLE("true")
        #                     xml.HIERARCHY_ORDINAL("1")
        #                     xml.DIMENSION_IS_SHARED("true")
        #                     xml.HIERARCHY_IS_VISIBLE("true")
        #                     xml.HIERARCHY_ORIGIN("1")
        #                     xml.INSTANCE_SELECTION("0")
        root = root_element_with_xsd(xml, mdschema_hierarchies_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                # if (
                #     request.Restrictions.RestrictionList.HIERARCHY_VISIBILITY == 3
                #     or request.Restrictions.RestrictionList.CATALOG_NAME == self.selected_cube
                # ):
                cube_s = Str(self.selected_cube.encode("utf8", "replace"))
                default_s = to_str(str(self.executor.measures[0]))
                for table_name, df in self.executor.tables_loaded.items():
                    if table_name == self.executor.facts:
                        continue

                    column_attribut = to_str(str(df.iloc[0][0]))
                    table_s = to_str(table_name)
                    # todo recheck
                    if (
                        request.Properties.PropertyList.Format
                        and request.Properties.PropertyList.Format.upper() == "TABULAR"
                    ):
                        # Format found in onlyoffice and not in excel
                        # ALL_MEMBER causes prob with excel
                        # row.stag("ALL_MEMBER").text(format(
                        #                                 "[{}].[{}].[{}]",
                        #                                 table_s,
                        #                                 table_s,
                        #                                 column_attribut,
                        #                             ))
                        column_attribut = to_str(str(df.iloc[0][0]))
                    else:
                        column_attribut = NULL

                    row = root.stag("row")
                    fill_mds_hier_table(row, cube_s, table_s, column_attribut)

                row = root.stag("row")
                fill_mds_hier_name(row, cube_s, default_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_levels_response(self, request):
        """Returns rowset contains information about the levels available in a
        dimension.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result, cube_s, col_s, table_s
        cdef int level

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(1)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_levels_xsd)
        #
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #                 for tables in self.executor.get_all_tables_names(
        #                     ignore_fact=True
        #                 ):
        #                     l_nb = 0
        #                     for col in self.executor.tables_loaded[tables].columns:
        #                         with xml.row:
        #                             xml.CATALOG_NAME(self.selected_cube)
        #                             xml.CUBE_NAME(self.selected_cube)
        #                             xml.DIMENSION_UNIQUE_NAME("[" + tables + "]")
        #                             xml.HIERARCHY_UNIQUE_NAME(
        #                                 "[{0}].[{0}]".format(tables)
        #                             )
        #                             xml.LEVEL_NAME(str(col))
        #                             xml.LEVEL_UNIQUE_NAME(
        #                                 "[{0}].[{0}].[{1}]".format(tables, col)
        #                             )
        #                             xml.LEVEL_CAPTION(str(col))
        #                             xml.LEVEL_NUMBER(str(l_nb))
        #                             xml.LEVEL_CARDINALITY("0")
        #                             xml.LEVEL_TYPE("0")
        #                             xml.CUSTOM_ROLLUP_SETTINGS("0")
        #                             xml.LEVEL_UNIQUE_SETTINGS("0")
        #                             xml.LEVEL_IS_VISIBLE("true")
        #                             xml.LEVEL_DBTYPE("130")
        #                             xml.LEVEL_KEY_CARDINALITY("1")
        #                             xml.LEVEL_ORIGIN("2")
        #                         l_nb += 1
        #
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.DIMENSION_UNIQUE_NAME("[Measures]")
        #                     xml.HIERARCHY_UNIQUE_NAME("[Measures]")
        #                     xml.LEVEL_NAME("MeasuresLevel")
        #                     xml.LEVEL_UNIQUE_NAME("[Measures]")
        #                     xml.LEVEL_CAPTION("MeasuresLevel")
        #                     xml.LEVEL_NUMBER("0")
        #                     xml.LEVEL_CARDINALITY("0")
        #                     xml.LEVEL_TYPE("0")
        #                     xml.CUSTOM_ROLLUP_SETTINGS("0")
        #                     xml.LEVEL_UNIQUE_SETTINGS("0")
        #                     xml.LEVEL_IS_VISIBLE("true")
        #                     xml.LEVEL_DBTYPE("130")
        #                     xml.LEVEL_KEY_CARDINALITY("1")
        #                     xml.LEVEL_ORIGIN("2")
        root = root_element_with_xsd(xml, mdschema_levels_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):

                self.change_cube(request.Properties.PropertyList.Catalog)
                cube_s = Str(self.selected_cube.encode("utf8", "replace"))

                for tables in self.executor.get_all_tables_names(ignore_fact=True):
                    level = 0 # FIXME BUG ?, should level be from 1
                    table_s = to_str(tables)
                    for col in self.executor.tables_loaded[tables].columns:
                        col_s = to_str(str(col))
                        row = root.stag("row")
                        fill_mds_levels_table(row, cube_s, table_s, col_s, level)
                        level += 1

                row = root.stag("row")
                fill_mds_levels_measure(row, cube_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_measuregroups_response(self, request):
        """Describes the measure groups.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result, cube_s

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_measuresgroups_xsd)
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.MEASUREGROUP_NAME("default")
        #                     xml.DESCRIPTION("-")
        #                     xml.IS_WRITE_ENABLED("true")
        #                     xml.MEASUREGROUP_CAPTION("default")
        root = root_element_with_xsd(xml, mdschema_measuresgroups_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                cube_s = Str(self.selected_cube.encode("utf8", "replace"))

                row = root.stag("row")
                fill_mds_measuregroups(row, cube_s)
        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_measuregroup_dimensions_response(self, request):
        """Enumerates the dimensions of the measure groups.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result, cube_s, table_s

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(1)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_measuresgroups_dimensions_xsd)
        #
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #                 # rows = ""
        #
        #                 for tables in self.executor.get_all_tables_names(
        #                     ignore_fact=True
        #                 ):
        #                     with xml.row:
        #                         xml.CATALOG_NAME(self.selected_cube)
        #                         xml.CUBE_NAME(self.selected_cube)
        #                         xml.MEASUREGROUP_NAME("default")
        #                         xml.MEASUREGROUP_CARDINALITY("ONE")
        #                         xml.DIMENSION_UNIQUE_NAME("[" + tables + "]")
        #                         xml.DIMENSION_CARDINALITY("MANY")
        #                         xml.DIMENSION_IS_VISIBLE("true")
        #                         xml.DIMENSION_IS_FACT_DIMENSION("false")
        #                         xml.DIMENSION_GRANULARITY("[{0}].[{0}]".format(tables))
        root = root_element_with_xsd(xml, mdschema_measuresgroups_dimensions_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
            ):

                self.change_cube(request.Properties.PropertyList.Catalog)
                cube_s = Str(self.selected_cube.encode("utf8", "replace"))
                for tables in self.executor.get_all_tables_names(ignore_fact=True):
                    table_s = to_str(tables)
                    row = root.stag("row")
                    fill_mds_measuregroup_dimensions(row, cube_s, table_s)
        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_properties_response(self, request):
        """PROPERTIES rowset contains information about the available
        properties for each level of the dimension.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str cube_s
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(1)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_properties_properties_xsd)
        #         if request.Restrictions.RestrictionList:
        #             if (
        #                 request.Restrictions.RestrictionList.PROPERTY_TYPE == 2
        #                 and request.Properties.PropertyList.Catalog is not None
        #             ):
        #                 properties_names = [
        #                     "FONT_FLAGS",
        #                     "LANGUAGE",
        #                     "style",
        #                     "ACTION_TYPE",
        #                     "FONT_SIZE",
        #                     "FORMAT_STRING",
        #                     "className",
        #                     "UPDATEABLE",
        #                     "BACK_COLOR",
        #                     "CELL_ORDINAL",
        #                     "FONT_NAME",
        #                     "VALUE",
        #                     "FORMATTED_VALUE",
        #                     "FORE_COLOR",
        #                 ]
        #                 properties_captions = [
        #                     "FONT_FLAGS",
        #                     "LANGUAGE",
        #                     "style",
        #                     "ACTION_TYPE",
        #                     "FONT_SIZE",
        #                     "FORMAT_STRING",
        #                     "className",
        #                     "UPDATEABLE",
        #                     "BACK_COLOR",
        #                     "CELL_ORDINAL",
        #                     "FONT_NAME",
        #                     "VALUE",
        #                     "FORMATTED_VALUE",
        #                     "FORE_COLOR",
        #                 ]
        #                 properties_datas = [
        #                     "3",
        #                     "19",
        #                     "130",
        #                     "19",
        #                     "18",
        #                     "130",
        #                     "130",
        #                     "19",
        #                     "19",
        #                     "19",
        #                     "130",
        #                     "12",
        #                     "130",
        #                     "19",
        #                 ]
        #
        #                 self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #                 for idx, prop_name in enumerate(properties_names):
        #                     with xml.row:
        #                         xml.CATALOG_NAME(self.selected_cube)
        #                         xml.PROPERTY_TYPE("2")
        #                         xml.PROPERTY_NAME(prop_name)
        #                         xml.PROPERTY_CAPTION(properties_captions[idx])
        #                         xml.DATA_TYPE(properties_datas[idx])
        root = root_element_with_xsd(xml, mdschema_properties_properties_xsd_s)
        if request.Restrictions.RestrictionList:
            if (
                request.Restrictions.RestrictionList.PROPERTY_TYPE == 2
                and request.Properties.PropertyList.Catalog is not None
            ):
                self.change_cube(request.Properties.PropertyList.Catalog)
                cube_s = Str(self.selected_cube.encode("utf8", "replace"))
                fill_mds_properties(root, cube_s)
        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_members_response(self, request):
        """Describes the members.

        :param request:
        :return:
        """
        # Enumeration of hierarchies in all dimensions

        cdef cypXML xml
        cdef Str result, cube_s, dim_unique_name, hier_unique_name,
        cdef Str level_unique_name, member_name, member_level_name
        cdef Str parent_unique_name, dot
        cdef cyplist[Str] members_s, tmp_lst, parent_level
        cdef int level_number

        dot = Str(".")

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_members_xsd)
        #         if request.Restrictions.RestrictionList:
        #             self.change_cube(request.Properties.PropertyList.Catalog)
        #
        #             if request.Restrictions.RestrictionList.MEMBER_UNIQUE_NAME:
        #                 member_lvl_name = (
        #                     request.Restrictions.RestrictionList.MEMBER_UNIQUE_NAME
        #                 )
        #             else:
        #                 member_lvl_name = (
        #                     request.Restrictions.RestrictionList.LEVEL_UNIQUE_NAME
        #                 )
        #
        #             separated_tuple = self.executor.parser.split_tuple(member_lvl_name)
        #             if (
        #                 request.Restrictions.RestrictionList.CUBE_NAME
        #                 == self.selected_cube
        #                 and request.Properties.PropertyList.Catalog is not None
        #                 and request.Restrictions.RestrictionList.TREE_OP == 8
        #             ):
        #
        #                 joined = ".".join(separated_tuple[:-1])
        #                 # exple
        #                 # separed_tuple -> [Product].[Product].[Company].[Crazy Development]
        #                 # joined -> [Product].[Product].[Company]
        #
        #                 last_attribut = "".join(
        #                     att for att in separated_tuple[-1] if att not in "[]"
        #                 ).replace("&", "&amp;")
        #
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.DIMENSION_UNIQUE_NAME(separated_tuple[0])
        #                     xml.HIERARCHY_UNIQUE_NAME(
        #                         "{0}.{0}".format(separated_tuple[0])
        #                     )
        #                     xml.LEVEL_UNIQUE_NAME(joined)
        #                     xml.LEVEL_NUMBER("0")
        #                     xml.MEMBER_ORDINAL("0")
        #                     xml.MEMBER_NAME(last_attribut)
        #                     xml.MEMBER_UNIQUE_NAME(member_lvl_name)
        #                     xml.MEMBER_TYPE("1")
        #                     xml.MEMBER_CAPTION(last_attribut)
        #                     xml.CHILDREN_CARDINALITY("1")
        #                     xml.PARENT_LEVEL("0")
        #                     xml.PARENT_COUNT("0")
        #                     xml.MEMBER_KEY(last_attribut)
        #                     xml.IS_PLACEHOLDERMEMBER("false")
        #                     xml.IS_DATAMEMBER("false")
        #
        #             elif member_lvl_name:
        #                 parent_level = [
        #                     "[" + tuple_att + "]" for tuple_att in separated_tuple[:-1]
        #                 ]
        #                 hierarchy_unique_name = ".".join(
        #                     ["[" + tuple_att + "]" for tuple_att in separated_tuple[:2]]
        #                 )
        #                 if len(separated_tuple) == 3:
        #                     level_unique_name = ".".join(
        #                         ["[" + tuple_att + "]" for tuple_att in separated_tuple]
        #                     )
        #                 else:
        #                     level_unique_name = ".".join(parent_level)
        #
        #                 with xml.row:
        #                     xml.CATALOG_NAME(self.selected_cube)
        #                     xml.CUBE_NAME(self.selected_cube)
        #                     xml.DIMENSION_UNIQUE_NAME("[" + separated_tuple[0] + "]")
        #                     xml.HIERARCHY_UNIQUE_NAME(hierarchy_unique_name)
        #                     xml.LEVEL_UNIQUE_NAME(level_unique_name)
        #                     xml.LEVEL_NUMBER(str(len(separated_tuple[2:])))
        #                     xml.MEMBER_ORDINAL("0")
        #                     xml.MEMBER_NAME(separated_tuple[-1])
        #                     xml.MEMBER_UNIQUE_NAME(member_lvl_name)
        #                     xml.MEMBER_TYPE("1")
        #                     xml.MEMBER_CAPTION(separated_tuple[-1])
        #                     xml.CHILDREN_CARDINALITY("1")
        #                     xml.PARENT_LEVEL("0")
        #                     xml.PARENT_COUNT("0")
        #                     xml.PARENT_UNIQUE_NAME(".".join(parent_level))
        #                     xml.MEMBER_KEY(separated_tuple[-1])
        #                     xml.IS_PLACEHOLDERMEMBER("false")
        #                     xml.IS_DATAMEMBER("false")
        root = root_element_with_xsd(xml, mdschema_members_xsd_s)
        if request.Restrictions.RestrictionList:
            self.change_cube(request.Properties.PropertyList.Catalog)
            cube_s = Str(self.selected_cube.encode("utf8", "replace"))

            if request.Restrictions.RestrictionList.MEMBER_UNIQUE_NAME:
                member_lvl_name = (
                    request.Restrictions.RestrictionList.MEMBER_UNIQUE_NAME
                )
            else:
                member_lvl_name = (
                    request.Restrictions.RestrictionList.LEVEL_UNIQUE_NAME
                )

            member_names = split_tuple(member_lvl_name)
            if (
                request.Restrictions.RestrictionList.CUBE_NAME == self.selected_cube
                and request.Properties.PropertyList.Catalog is not None
                and request.Restrictions.RestrictionList.TREE_OP == 8
            ):

                dot_names = ".".join(member_names[:-1])
                # exple
                # separed_tuple -> [Product].[Product].[Company].[Crazy Development]
                # joined -> [Product].[Product].[Company]
                # FIXME BAD COMMENT, separed_tuple not good. Actually it is:
                # member_lvl_name -> [Product].[Product].[Company].[Crazy Development]
                # member_names -> "Product", "Product", "Company", "Crazy Development"
                # dot_names -> "Product.Product.Company"


                last_name = "".join(
                    att for att in member_names[-1] if att not in "[]"
                ).replace("&", "&amp;")

                dim_unique_name = Str(member_names[0].encode("utf8", "replace"))
                level_unique_name = Str(dot_names.encode("utf8", "replace"))
                member_name = Str(last_name.encode("utf8", "replace"))
                member_level_name = Str(member_lvl_name.encode("utf8", "replace"))

                row = root.stag("row")
                fill_mds_members_a(
                    row,
                    cube_s,
                    dim_unique_name,
                    level_unique_name,
                    member_name,
                    member_level_name,
                )

            elif member_lvl_name:
                # parent_level = [
                #     "[" + tuple_att + "]" for tuple_att in separated_tuple[:-1]
                # ]
                # hierarchy_unique_name = ".".join(
                #     ["[" + tuple_att + "]" for tuple_att in separated_tuple[:2]]
                # )
                # if len(separated_tuple) == 3:
                #     level_unique_name = ".".join(
                #         ["[" + tuple_att + "]" for tuple_att in separated_tuple]
                #     )
                # else:
                #     level_unique_name = ".".join(parent_level)

                row = root.stag("row")
                # members_s = cyplist[Str]()
                members_s = pylist_to_cyplist(member_names)
                parent_level = cypstr_copy_slice_to(members_s, members_s.__len__() - 1)
                if members_s.__len__() == 3:
                    level_unique_name = dot_bracket(members_s)
                else:
                    level_unique_name = dot_bracket(parent_level)
                # FIXME the previous call has no [] on dim_unique_name ?
                dim_unique_name = bracket(members_s[0])
                tmp_lst = cypstr_copy_slice_to(members_s, 2)
                hier_unique_name = dot_bracket(tmp_lst)
                member_name = members_s[-1]
                member_level_name = Str(member_lvl_name.encode("utf8", "replace"))
                level_number = (<int>members_s.__len__()) - 2
                if level_number < 0:
                    level_number = 0
                tmp_lst = cypstr_copy_slice_to(members_s, members_s.__len__() - 1)
                parent_unique_name = dot_bracket(parent_level)

                fill_mds_members_b(
                    row,
                    cube_s,
                    dim_unique_name,
                    hier_unique_name,
                    level_unique_name,
                    member_name,
                    member_level_name,
                    level_number,
                    parent_unique_name
                )
                # row.stag("CATALOG_NAME").text(to_str(self.selected_cube))
                # row.stag("CUBE_NAME").text(to_str(self.selected_cube))
                # row.stag("DIMENSION_UNIQUE_NAME").text(to_str(
                #                                     "[" + separated_tuple[0] + "]"))
                # row.stag("HIERARCHY_UNIQUE_NAME").text(to_str(hierarchy_unique_name))
                # row.stag("LEVEL_UNIQUE_NAME").text(to_str(level_unique_name))
                # row.stag("LEVEL_NUMBER").text(to_str(str(len(separated_tuple[2:]))))
                # row.stag("MEMBER_ORDINAL").stext("0")
                # row.stag("MEMBER_NAME").text(to_str(str(separated_tuple[-1])))
                # row.stag("MEMBER_UNIQUE_NAME").text(to_str(member_lvl_name))
                # row.stag("MEMBER_TYPE").stext("1")
                # row.stag("MEMBER_CAPTION").text(to_str(str(separated_tuple[-1])))
                # row.stag("CHILDREN_CARDINALITY").stext("1")
                # row.stag("PARENT_LEVEL").stext("0")
                # row.stag("PARENT_COUNT").stext("0")
                # row.stag("PARENT_UNIQUE_NAME").text(to_str(".".join(parent_level)))
                # row.stag("MEMBER_KEY").text(to_str(separated_tuple[-1]))
                # row.stag("IS_PLACEHOLDERMEMBER").stext("false")
                # row.stag("IS_DATAMEMBER").stext("false")

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def discover_instances_response(self, request):
        """todo.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_schema_rowsets_xsd)
        root = root_element_with_xsd(xml, discover_schema_rowsets_xsd_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def dmschema_mining_models_response(self, request):
        """todo.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_schema_rowsets_xsd)
        root = root_element_with_xsd(xml, discover_schema_rowsets_xsd_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_actions_response(self, request):
        """todo.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_schema_rowsets_xsd)
        root = root_element_with_xsd(xml, discover_schema_rowsets_xsd_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_functions_response(self, request):
        """todo.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(mdschema_functions_xsd)
        root = root_element_with_xsd(xml, mdschema_functions_xsd_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def mdschema_input_datasources_response(self, request):
        """todo.

        :param request:
        :return:
        """
        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_schema_rowsets_xsd)
        root = root_element_with_xsd(xml, discover_schema_rowsets_xsd_s)

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def discover_enumerators_response(self, request):
        """todo."""

        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_enumerators_xsd)
        #
        #         with xml.row:
        #             xml.EnumName("ProviderType")
        #             xml.ElementName("TDP")
        #             xml.EnumType("string")
        root = root_element_with_xsd(xml, discover_enumerators_xsd_s)
        row = root.stag("row")
        row.stag("EnumName").stext("ProviderType")
        row.stag("ElementName").stext("TDP")
        row.stag("EnumType").stext("string")

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")

    def discover_keywords_response(self, request):
        """todo."""

        cdef cypXML xml
        cdef Str result

        # xml = xmlwitch.Builder()
        xml = cypXML()
        xml.set_max_depth(0)
        # with xml["return"]:
        #     with xml.root(
        #         xmlns="urn:schemas-microsoft-com:xml-analysis:rowset",
        #         **{
        #             "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
        #             "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        #         },
        #     ):
        #         xml.write(discover_keywords_xsd)
        #         with xml.row:
        #             xml.Keyword("aggregate")
        #             xml.Keyword("ancestors")
        root = root_element_with_xsd(xml, discover_keywords_xsd_s)
        row = root.stag("row")
        row.stag("Keyword").stext("aggregate")
        row.stag("Keyword").stext("ancestors")

        # return str(xml)
        result = xml.dump()
        return result.bytes().decode("utf8")
