import { TabulatorFull as Tabulator } from 'tabulator-tables';

export default function () {
  let exifWrapper = document.querySelector('#exif-details');
  if (exifWrapper && exifWrapper.dataset.exif !== undefined) {
    const objectArray = Object.entries(JSON.parse(exifWrapper.dataset.exif));
    const transformedTableData = objectArray.map(([key, value]) => {
      return { name: key, value: value };
    });

    new Tabulator(exifWrapper, {
      data: transformedTableData,
      layout: 'fitColumns', //fit columns to width of table (optional)
      columns: [
        //Define Table Columns
        { title: 'Name', field: 'name' },
        { title: 'Wert', field: 'value' }
      ],
      initialSort: [
        { column: 'name', dir: 'asc' } //sort by this first
      ]
    });
  }
}
