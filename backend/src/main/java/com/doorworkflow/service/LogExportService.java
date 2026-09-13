package com.doorworkflow.service;

import com.doorworkflow.entity.JobStepHistory;
import com.doorworkflow.repository.JobStepHistoryRepository;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
public class LogExportService {

    private static final String SHEET_NAME = "Job Logs";
    private static final String[] HEADERS = {
            "Job Number",
            "Company Name",
            "Job Status",
            "Chalan Number",
            "Step Name",
            "Action",
            "Performed By",
            "Timestamp"
    };

    private static final DateTimeFormatter TIMESTAMP_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss").withZone(ZoneId.of("UTC"));

    private final JobStepHistoryRepository jobStepHistoryRepository;

    public LogExportService(JobStepHistoryRepository jobStepHistoryRepository) {
        this.jobStepHistoryRepository = jobStepHistoryRepository;
    }

    @Transactional(readOnly = true)
    public byte[] generateJobLogsExcel() {
        List<JobStepHistory> logs = jobStepHistoryRepository.findAllWithDetailsOrderByCreatedAtDesc();

        try (Workbook workbook = new XSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {

            Sheet sheet = workbook.createSheet(SHEET_NAME);
            sheet.createFreezePane(0, 1);

            // Header Style
            CellStyle headerStyle = workbook.createCellStyle();
            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerFont.setColor(IndexedColors.BLACK.getIndex());
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            headerStyle.setBorderBottom(BorderStyle.THIN);
            headerStyle.setBorderTop(BorderStyle.THIN);
            headerStyle.setBorderLeft(BorderStyle.THIN);
            headerStyle.setBorderRight(BorderStyle.THIN);
            headerStyle.setAlignment(HorizontalAlignment.LEFT);

            // Regular Data Cell Style (optional borders for clean tabular view)
            CellStyle textStyle = workbook.createCellStyle();
            DataFormat dataFormat = workbook.createDataFormat();
            textStyle.setDataFormat(dataFormat.getFormat("@")); // text format

            // Create Header Row
            Row headerRow = sheet.createRow(0);
            for (int col = 0; col < HEADERS.length; col++) {
                Cell cell = headerRow.createCell(col);
                cell.setCellValue(HEADERS[col]);
                cell.setCellStyle(headerStyle);
            }

            // Create Data Rows
            int rowIdx = 1;
            for (JobStepHistory log : logs) {
                Row row = sheet.createRow(rowIdx++);

                // 0: Job Number
                String jobNumber = log.getJob() != null ? log.getJob().getJobNumber() : "";
                row.createCell(0).setCellValue(jobNumber);

                // 1: Company Name
                String companyName = log.getJob() != null ? log.getJob().getCompanyName() : "";
                row.createCell(1).setCellValue(companyName);

                // 2: Job Status
                String jobStatus = (log.getJob() != null && log.getJob().getStatus() != null)
                        ? log.getJob().getStatus().name()
                        : "";
                row.createCell(2).setCellValue(jobStatus);

                // 3: Chalan Number (displayed explicitly as text)
                String chalanNumber = (log.getJob() != null && log.getJob().getChalanNumber() != null)
                        ? log.getJob().getChalanNumber()
                        : "";
                Cell chalanCell = row.createCell(3);
                chalanCell.setCellValue(chalanNumber);
                chalanCell.setCellStyle(textStyle);

                // 4: Step Name (blank for job-level events like CHALAN_ADDED, JOB_COMPLETED)
                String stepName = (log.getJobStep() != null && log.getJobStep().getStepName() != null)
                        ? log.getJobStep().getStepName()
                        : "";
                row.createCell(4).setCellValue(stepName);

                // 5: Action
                String action = log.getAction() != null ? log.getAction().name() : "";
                row.createCell(5).setCellValue(action);

                // 6: Performed By
                String performedBy = log.getPerformedBy() != null ? log.getPerformedBy().getName() : "";
                row.createCell(6).setCellValue(performedBy);

                // 7: Timestamp
                String timestamp = log.getCreatedAt() != null
                        ? TIMESTAMP_FORMATTER.format(log.getCreatedAt())
                        : "";
                row.createCell(7).setCellValue(timestamp);
            }

            // Auto-size columns
            for (int col = 0; col < HEADERS.length; col++) {
                sheet.autoSizeColumn(col);
            }

            workbook.write(out);
            return out.toByteArray();
        } catch (IOException e) {
            throw new RuntimeException("Failed to generate Excel export", e);
        }
    }
}
