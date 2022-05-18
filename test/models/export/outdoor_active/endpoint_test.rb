# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

JOB_STATUS_WITH_NO_ERRORS_OR_WARNINGS = <<-EOS
  <update key="datacycle-kaernten" createdAt="2019-06-12 10:16:30" finishedAt="2019-06-12 10:16:32" runTime="1.59s" lastUpdate="2019-06-12 07:43:09" state="done">
    <sourceUrl>http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&amp;ids=bdedcb72-c29b-4ae3-ba70-4cddf2fd4725</sourceUrl>
    <stat contentCount="3" age="18.30s" dataSize="19578"/>
    <details>
      <content action="update" type="lodging" id="bdedcb72-c29b-4ae3-ba70-4cddf2fd4725" cmsId="34214262" status="success">
      </content>
      <content action="update" type="imagemeta" id="a52540cc-1b33-4f29-a3f7-330f558eba8f" cmsId="38923838" status="unchanged">
      </content>
      <content action="update" type="imagemeta" id="0521aa87-304a-444a-9c99-254ac2d82e8a" cmsId="38923839" status="unchanged">
      </content>
    </details>
  </update>
EOS

JOB_STATUS_WITH_INVALID_CONTENT_ERRORS = <<-EOS
  <update key="datacycle-kaernten" createdAt="2019-06-12 07:43:05" finishedAt="2019-06-12 07:53:21" runTime="10:17(mm:ss)" lastUpdate="2019-06-12 07:43:05" state="done">
    <sourceUrl>http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&amp;ids=a98db120-9619-4e9b-a8a0-356314690103</sourceUrl>
    <stat contentCount="2" skipUpdateCount="1" age="18:29(mm:ss)" dataSize="1420"/>
    <errors>
      <error errorType="invalidContent" count="1"/>
    </errors>
    <details>
      <content action="create" type="poi" id="a98db120-9619-4e9b-a8a0-356314690103" cmsId="39448462" status="data-skip">
        <invalidContent>Invalid data category</invalidContent>
      </content>
      <content action="create" type="imagemeta" id="bf32e43e-b367-4441-bafb-756679c45921" status="data-skip">
      </content>
    </details>
  </update>
EOS

JOB_STATUS_WITH_SERIOUS_WARNING = <<-EOS
  <update key="datacycle-kaernten" createdAt="2020-11-26 13:42:04" finishedAt="2020-11-26 13:42:04" lastUpdate="2020-11-26 13:42:04" state="warning">
    <sourceUrl>http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&amp;ids=7ec5a968-919b-4815-90da-439c690fb189</sourceUrl>
    <message><![CDATA[You can run the service Service 1972730148 AlpInterfaceUpdater has 200 open events
    open event at 2020-11-26T13:41:46: InterfaceUpdateEvent source datacycle-kaerntenin job 2733328408997770056: http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&ids=61af42ae-f761-4903-95f8-5c32a2ec440d
    open event at 2020-11-26T13:41:44: InterfaceUpdateEvent source datacycle-kaerntenin job 2732835832083493708: http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&ids=fe7870ed-94f5-4c07-aa26-3fb68970805c
    open event at 2020-11-26T13:41:45: InterfaceUpdateEvent source datacycle-kaerntenin job 2724391853365115724: http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&ids=b82be421-86ae-430a-98da-ab9d633d78fd
    open event at 2020-11-26T13:41:48: InterfaceUpdateEvent source datacycle-kaerntenin job 2723758534667531086: http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&ids=cc78b257-561b-4569-a54a-d6312117df94
    open event at 2020-11-26T13:41:51: InterfaceUpdateEvent source datacycle-kaerntenin job 2733328413292755790: http://datacycle.kaernten.at/api/v2/external_systems/ed979c1a-c582-40ea-adcd-a1ac0b6dd0db/?token=44fddbf821b107fa572c952cd98d8e85&ids=1c5e62cd-5528-4ecd-8644-09c1738865c4
   -1 times on the same time]]></message>
  </update>
EOS

describe DataCycleCore::Export::OutdoorActive::Endpoint do
  let(:endpoint) do
    DataCycleCore::Export::OutdoorActive::Endpoint.new
  end

  it 'should parse successfull job status' do
    result = endpoint.parse_job_status_response_body(raw_response_body: JOB_STATUS_WITH_NO_ERRORS_OR_WARNINGS, job_id: '123456')
    assert(result.present?)
    assert(result['outdoor_active_id'], '34214262')
    assert(result['job_status'], 'done')
    assert_nil(result['errors'])
    assert_nil(result['warnings'])
  end

  it 'should parse job status containing invalid content errors' do
    result = endpoint.parse_job_status_response_body(raw_response_body: JOB_STATUS_WITH_INVALID_CONTENT_ERRORS, job_id: '123456')

    assert(result.present?)
    assert(result['outdoor_active_id'], '39448462')
    assert(result['job_status'], 'failed')
    assert(result['errors'].include?('Invalid data category'))
  end

  it 'should parse job status containing an jobstatus failed' do
    result = endpoint.parse_job_status_response_body(raw_response_body: JOB_STATUS_WITH_SERIOUS_WARNING, job_id: '123456')

    assert(result.present?)
    assert(result['job_status'], 'failed')
  end
end
