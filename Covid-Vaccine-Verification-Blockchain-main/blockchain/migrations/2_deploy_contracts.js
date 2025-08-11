const VaccinationRegistry = artifacts.require("VaccinationRegistry");

module.exports = async function (deployer, network, accounts) {
  console.log('🚀 Deploying VaccinationRegistry...');
  console.log('Network:', network);
  console.log('Deployer account:', accounts[0]);
  
  // Deploy the contract
  await deployer.deploy(VaccinationRegistry);
  const registry = await VaccinationRegistry.deployed();
  
  console.log('✅ VaccinationRegistry deployed at:', registry.address);
  console.log('📝 Contract owner:', accounts[0]);
  
  // Setup test hospitals for development
  if (network === 'development' || network === 'ganache') {
    console.log('🏥 Setting up test hospitals...');
    
    const testHospitals = [
      {
        address: accounts[1],
        name: "City General Hospital",
        license: "CGH-2024-001",
        contact: "admin@citygeneral.com"
      },
      {
        address: accounts[2], 
        name: "Children's Medical Center",
        license: "CMC-2024-002",
        contact: "info@childrenmedical.com"
      },
      {
        address: accounts[3],
        name: "Metro Health Clinic", 
        license: "MHC-2024-003",
        contact: "contact@metrohealth.com"
      }
    ];

    try {
      for (let i = 0; i < testHospitals.length; i++) {
        const hospital = testHospitals[i];
        
        // Register hospital (this will be done by the hospital itself)
        console.log(`📝 Registering ${hospital.name}...`);
        await registry.registerHospital(
          hospital.name,
          hospital.license, 
          hospital.contact,
          { from: hospital.address }
        );
        
        // Authorize hospital (this is done by contract owner)
        console.log(`✅ Authorizing ${hospital.name}...`);
        await registry.setHospitalAuthorization(
          hospital.address, 
          true,
          { from: accounts[0] }
        );
      }
      
      console.log('🎉 Test hospitals setup complete!');
      
    } catch (error) {
      console.error('❌ Error setting up test hospitals:', error);
    }
  }
  
  // Display deployment information
  console.log('\n📋 DEPLOYMENT SUMMARY');
  console.log('========================');
  console.log('Contract Address:', registry.address);
  console.log('Network:', network);
  console.log('Owner Account:', accounts[0]);
  console.log('Gas Used: Check transaction receipt');
  
  if (network === 'development' || network === 'ganache') {
    console.log('\n🔧 DEVELOPMENT SETUP');
    console.log('===================');
    console.log('Test Hospitals:');
    console.log('- Account 1:', accounts[1], '(City General Hospital)');
    console.log('- Account 2:', accounts[2], '(Children\'s Medical Center)');
    console.log('- Account 3:', accounts[3], '(Metro Health Clinic)');
    console.log('\n📝 Update App.js CONTRACT_ADDRESS to:', registry.address);
  }
  
  console.log('\n🚀 Ready to use!');
};