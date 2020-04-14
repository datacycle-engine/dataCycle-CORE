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
    assert_nil(result['outdoor_active_id'])
    assert(result['job_status'], 'failed')
    assert(result['errors'].include?('Invalid data category'))
  end
end
