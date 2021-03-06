require 'rails_helper'

describe Study do

  # creating an article indexes
  # the article in ES which causes
  # problems for WebMock.
  before(:all) { WebMock.disable! }
  after(:all) { WebMock.enable! }

  let(:article) do
    Article.create(
      title: 'Z Article',
      doi: 'http://dx.doi.org/10.6084/m9.figshare.949676',
      publication_date: Time.now - 3.days,
      abstract: 'hello world'
    )
  end
  let(:study) do
    Study.create({
        article_id: article.id
    })
  end
  let(:replicating_study) do
    Study.create({
        article_id: article.id
    })
  end

  describe "create" do

    it "should not allow study to be created without article_id" do
      study = Study.create({})

      study.errors.count.should == 1
      field, error = study.errors.first
      field.should == :article_id
      study.errors[field].first.should == "can't be blank"
    end

    it "should initialize variables as an array" do
      study.dependent_variables.kind_of?(Array).should == true
      study.independent_variables.kind_of?(Array).should == true
    end

    it "should initialize effect_size with an empty hash" do
      study.effect_size.kind_of?(Hash).should == true
    end
  end

  describe "add variables" do
    it "should persist dependent variables that are added" do
      study.add_dependent_variables('reaction time').save!
      study.reload
      study.dependent_variables.should include('reaction time')
    end

    it "should persist independent variables that are added" do
      study.add_independent_variables('thc').save!
      study.reload
      study.independent_variables.should include('thc')
    end
  end

  describe "n" do
    it "should raise an error when set negative" do
      study.n = -1
      study.save
      study.errors.count.should == 1
      field, error = study.errors.first
      field.should == :n
      study.errors[field].first.should == "must be greater than 0"
    end

    it "should raise an error when 0" do
      study.n = 0
      study.save
      study.errors.count.should == 1
      field, error = study.errors.first
      field.should == :n
      study.errors[field].first.should == "must be greater than 0"
    end

    it "should raise an error when not an integer" do
      study.n = 1.3
      study.save
      study.errors.count.should == 1
      field, error = study.errors.first
      field.should == :n
      study.errors[field].first.should == "must be an integer"
    end
  end

  describe "power" do
    it "should raise an error when set negative" do
      study.power = -1
      study.save
      study.errors.count.should == 1
      field, error = study.errors.first
      field.should == :power
      study.errors[field].first.should == "must be greater than 0"
    end

    it "should raise an error when above 1" do
      study.power = 2
      study.save
      study.errors.count.should == 1
      field, error = study.errors.first
      field.should == :power
      study.errors[field].first.should == "must be less than 1"
    end
  end

  describe "set_effect_size" do
    it "should raise an exception, if it is not a known statistical test" do
      expect { study.set_effect_size(:banana, 0.3) }
        .to raise_error(Exceptions::InvalidEffectSize)
    end

    it "should set_effect_size, if statistical test is known" do
      study.set_effect_size('d', 0.3).save!
      study.reload
      study.effect_size['d'].should == 0.3
    end

    it "should only allow for one effect size per study" do
      study.set_effect_size('d', 0.3)
      study.set_effect_size('r', 0.3)
      study.save!
      study.reload

      study.effect_size.keys.count.should == 1
    end
  end

  describe "article" do
    it "can lookup an article by the study" do
      study.article.should == article
    end
  end

  describe "findings" do
    it "allows a finding to be created for a study" do
      study.findings.create({
        name: 'findings.txt',
        url: 'https://www.example.com/'
      })
      study.findings.create({
        name: 'findings2.txt',
        url: 'https://www.example2.com/'
      })

      study.findings.count.should == 2
      finding = study.findings.first
      finding.name.should == 'findings.txt'
      finding.url.should == 'https://www.example.com/'
    end
  end

  describe "links" do
    it "allows a link to be created for a study" do
      study.links.create({
        name: 'link1.txt',
        url: 'https://www.example.com/',
        type: 'finding'
      })
      study.links.create({
        name: 'link2.txt',
        url: 'https://www.example2.com/',
        type: 'material'
      })

      study.links.count.should == 2
      link = study.links.first
      link.name.should == 'link1.txt'
      link.url.should == 'https://www.example.com/'
      link.type.should == 'finding'
    end
  end

  describe "to_json" do
    it "should include findings" do
      study.findings.create({
        name: 'findings.txt',
        url: 'https://www.example.com/'
      })
      study.as_json(findings: true)[:findings].count.should == 1
    end

    it "should include materials" do
      study.materials.create({
        name: 'materials.txt',
        url: 'https://www.example.com/'
      })
      study.as_json(materials: true)[:materials].count.should == 1
    end

    it "should include registrations" do
      study.registrations.create({
        name: 'registrations.txt',
        url: 'https://www.example.com/'
      })
      study.as_json(registrations: true)[:registrations].count.should == 1
    end

    it "should include links" do
      study.links.create({
        name: 'link1.txt',
        url: 'https://www.example.com/',
        type: 'finding'
      })
      study.as_json(links: true)[:links].count.should == 1
    end

    it "should return repliating studies, if replications flag is set" do
      study.add_replication(replicating_study, 3)
      study_json = study.as_json(replications: true)
      study_json[:replications].count.should == 1
      study_json[:replications][0][:replicating_study]['id'].should == replicating_study.id
    end

    it "should return studies that a study replicates, if replication_of flag is set" do
      study.add_replication(replicating_study, 3)
      study_json = replicating_study.as_json(replication_of: true)
      study_json[:replication_of].count.should == 1
      study_json[:replication_of][0][:study]['id'].should == study.id
    end
  end

  describe "add_replication" do
    it "should allow a replication to be added without a closeness" do
      study.add_replication(replicating_study)

      study.reload
      study.replications.count.should == 1
      replication = study.replications.first
      replication.study.should == study
      replication.replicating_study.should == replicating_study
      replication.closeness.should == 0
    end

    it "should allow a replication to be added with a closeness" do
      study.add_replication(replicating_study, 33)
      study.reload
      replication = study.replications.first
      replication.closeness.should == 33
    end
  end

end
