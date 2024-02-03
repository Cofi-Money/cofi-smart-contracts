
async function main() {

    const start     = 1000000000
    const end       = 990099009 // rcpt after 1% increase
    const period    = 30

    console.log(start / end)
    console.log(365.25 / period)
    const apy = (start / end)^(365.25 / period) -1
    console.log(apy)

    
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});